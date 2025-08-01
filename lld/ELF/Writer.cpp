//===- Writer.cpp ---------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "Writer.h"
#include "AArch64ErrataFix.h"
#include "ARMErrataFix.h"
#include "BPSectionOrderer.h"
#include "CallGraphSort.h"
#include "Config.h"
#include "InputFiles.h"
#include "LinkerScript.h"
#include "MapFile.h"
#include "OutputSections.h"
#include "Relocations.h"
#include "SymbolTable.h"
#include "Symbols.h"
#include "SyntheticSections.h"
#include "Target.h"
#include "lld/Common/Arrays.h"
#include "lld/Common/CommonLinkerContext.h"
#include "lld/Common/Filesystem.h"
#include "lld/Common/Strings.h"
#include "llvm/ADT/STLExtras.h"
#include "llvm/ADT/StringMap.h"
#include "llvm/Support/BLAKE3.h"
#include "llvm/Support/Parallel.h"
#include "llvm/Support/RandomNumberGenerator.h"
#include "llvm/Support/TimeProfiler.h"
#include "llvm/Support/xxhash.h"
#include <climits>

#define DEBUG_TYPE "lld"

using namespace llvm;
using namespace llvm::ELF;
using namespace llvm::object;
using namespace llvm::support;
using namespace llvm::support::endian;
using namespace lld;
using namespace lld::elf;

namespace {
// The writer writes a SymbolTable result to a file.
template <class ELFT> class Writer {
public:
  LLVM_ELF_IMPORT_TYPES_ELFT(ELFT)

  Writer(Ctx &ctx) : ctx(ctx), buffer(ctx.e.outputBuffer), tc(ctx) {}

  void run();

private:
  void addSectionSymbols();
  void sortSections();
  void resolveShfLinkOrder();
  void finalizeAddressDependentContent();
  void optimizeBasicBlockJumps();
  void sortInputSections();
  void sortOrphanSections();
  void finalizeSections();
  void checkExecuteOnly();
  void checkExecuteOnlyReport();
  void setReservedSymbolSections();

  SmallVector<std::unique_ptr<PhdrEntry>, 0> createPhdrs(Partition &part);
  void addPhdrForSection(Partition &part, unsigned shType, unsigned pType,
                         unsigned pFlags);
  void assignFileOffsets();
  void assignFileOffsetsBinary();
  void setPhdrs(Partition &part);
  void checkSections();
  void fixSectionAlignments();
  void openFile();
  void writeTrapInstr();
  void writeHeader();
  void writeSections();
  void writeSectionsBinary();
  void writeBuildId();

  Ctx &ctx;
  std::unique_ptr<FileOutputBuffer> &buffer;
  // ThunkCreator holds Thunks that are used at writeTo time.
  ThunkCreator tc;

  void addRelIpltSymbols();
  void addStartEndSymbols();
  void addStartStopSymbols(OutputSection &osec);

  uint64_t fileSize;
  uint64_t sectionHeaderOff;
};
} // anonymous namespace

template <class ELFT> void elf::writeResult(Ctx &ctx) {
  Writer<ELFT>(ctx).run();
}

static void
removeEmptyPTLoad(Ctx &ctx, SmallVector<std::unique_ptr<PhdrEntry>, 0> &phdrs) {
  auto it = std::stable_partition(phdrs.begin(), phdrs.end(), [&](auto &p) {
    if (p->p_type != PT_LOAD)
      return true;
    if (!p->firstSec)
      return false;
    uint64_t size = p->lastSec->addr + p->lastSec->size - p->firstSec->addr;
    return size != 0;
  });

  // Clear OutputSection::ptLoad for sections contained in removed
  // segments.
  DenseSet<PhdrEntry *> removed;
  for (auto it2 = it; it2 != phdrs.end(); ++it2)
    removed.insert(it2->get());
  for (OutputSection *sec : ctx.outputSections)
    if (removed.count(sec->ptLoad))
      sec->ptLoad = nullptr;
  phdrs.erase(it, phdrs.end());
}

void elf::copySectionsIntoPartitions(Ctx &ctx) {
  SmallVector<InputSectionBase *, 0> newSections;
  const size_t ehSize = ctx.ehInputSections.size();
  for (unsigned part = 2; part != ctx.partitions.size() + 1; ++part) {
    for (InputSectionBase *s : ctx.inputSections) {
      if (!(s->flags & SHF_ALLOC) || !s->isLive() || s->type != SHT_NOTE)
        continue;
      auto *copy = make<InputSection>(cast<InputSection>(*s));
      copy->partition = part;
      newSections.push_back(copy);
    }
    for (size_t i = 0; i != ehSize; ++i) {
      assert(ctx.ehInputSections[i]->isLive());
      auto *copy = make<EhInputSection>(*ctx.ehInputSections[i]);
      copy->partition = part;
      ctx.ehInputSections.push_back(copy);
    }
  }

  ctx.inputSections.insert(ctx.inputSections.end(), newSections.begin(),
                           newSections.end());
}

static Defined *addOptionalRegular(Ctx &ctx, StringRef name, SectionBase *sec,
                                   uint64_t val, uint8_t stOther = STV_HIDDEN) {
  Symbol *s = ctx.symtab->find(name);
  if (!s || s->isDefined() || s->isCommon())
    return nullptr;

  ctx.synthesizedSymbols.push_back(s);
  s->resolve(ctx, Defined{ctx, ctx.internalFile, StringRef(), STB_GLOBAL,
                          stOther, STT_NOTYPE, val,
                          /*size=*/0, sec});
  s->isUsedInRegularObj = true;
  return cast<Defined>(s);
}

// The linker is expected to define some symbols depending on
// the linking result. This function defines such symbols.
void elf::addReservedSymbols(Ctx &ctx) {
  if (ctx.arg.emachine == EM_MIPS) {
    auto addAbsolute = [&](StringRef name) {
      Symbol *sym =
          ctx.symtab->addSymbol(Defined{ctx, ctx.internalFile, name, STB_GLOBAL,
                                        STV_HIDDEN, STT_NOTYPE, 0, 0, nullptr});
      sym->isUsedInRegularObj = true;
      return cast<Defined>(sym);
    };
    // Define _gp for MIPS. st_value of _gp symbol will be updated by Writer
    // so that it points to an absolute address which by default is relative
    // to GOT. Default offset is 0x7ff0.
    // See "Global Data Symbols" in Chapter 6 in the following document:
    // ftp://www.linux-mips.org/pub/linux/mips/doc/ABI/mipsabi.pdf
    ctx.sym.mipsGp = addAbsolute("_gp");

    // On MIPS O32 ABI, _gp_disp is a magic symbol designates offset between
    // start of function and 'gp' pointer into GOT.
    if (ctx.symtab->find("_gp_disp"))
      ctx.sym.mipsGpDisp = addAbsolute("_gp_disp");

    // The __gnu_local_gp is a magic symbol equal to the current value of 'gp'
    // pointer. This symbol is used in the code generated by .cpload pseudo-op
    // in case of using -mno-shared option.
    // https://sourceware.org/ml/binutils/2004-12/msg00094.html
    if (ctx.symtab->find("__gnu_local_gp"))
      ctx.sym.mipsLocalGp = addAbsolute("__gnu_local_gp");
  } else if (ctx.arg.emachine == EM_PPC) {
    // glibc *crt1.o has a undefined reference to _SDA_BASE_. Since we don't
    // support Small Data Area, define it arbitrarily as 0.
    addOptionalRegular(ctx, "_SDA_BASE_", nullptr, 0, STV_HIDDEN);
  } else if (ctx.arg.emachine == EM_PPC64) {
    addPPC64SaveRestore(ctx);
  }

  // The Power Architecture 64-bit v2 ABI defines a TableOfContents (TOC) which
  // combines the typical ELF GOT with the small data sections. It commonly
  // includes .got .toc .sdata .sbss. The .TOC. symbol replaces both
  // _GLOBAL_OFFSET_TABLE_ and _SDA_BASE_ from the 32-bit ABI. It is used to
  // represent the TOC base which is offset by 0x8000 bytes from the start of
  // the .got section.
  // We do not allow _GLOBAL_OFFSET_TABLE_ to be defined by input objects as the
  // correctness of some relocations depends on its value.
  StringRef gotSymName =
      (ctx.arg.emachine == EM_PPC64) ? ".TOC." : "_GLOBAL_OFFSET_TABLE_";

  if (Symbol *s = ctx.symtab->find(gotSymName)) {
    if (s->isDefined()) {
      ErrAlways(ctx) << s->file << " cannot redefine linker defined symbol '"
                     << gotSymName << "'";
      return;
    }

    uint64_t gotOff = 0;
    if (ctx.arg.emachine == EM_PPC64)
      gotOff = 0x8000;

    s->resolve(ctx, Defined{ctx, ctx.internalFile, StringRef(), STB_GLOBAL,
                            STV_HIDDEN, STT_NOTYPE, gotOff, /*size=*/0,
                            ctx.out.elfHeader.get()});
    ctx.sym.globalOffsetTable = cast<Defined>(s);
  }

  // __ehdr_start is the location of ELF file headers. Note that we define
  // this symbol unconditionally even when using a linker script, which
  // differs from the behavior implemented by GNU linker which only define
  // this symbol if ELF headers are in the memory mapped segment.
  addOptionalRegular(ctx, "__ehdr_start", ctx.out.elfHeader.get(), 0,
                     STV_HIDDEN);

  // __executable_start is not documented, but the expectation of at
  // least the Android libc is that it points to the ELF header.
  addOptionalRegular(ctx, "__executable_start", ctx.out.elfHeader.get(), 0,
                     STV_HIDDEN);

  // __dso_handle symbol is passed to cxa_finalize as a marker to identify
  // each DSO. The address of the symbol doesn't matter as long as they are
  // different in different DSOs, so we chose the start address of the DSO.
  addOptionalRegular(ctx, "__dso_handle", ctx.out.elfHeader.get(), 0,
                     STV_HIDDEN);

  // If linker script do layout we do not need to create any standard symbols.
  if (ctx.script->hasSectionsCommand)
    return;

  auto add = [&](StringRef s, int64_t pos) {
    return addOptionalRegular(ctx, s, ctx.out.elfHeader.get(), pos,
                              STV_DEFAULT);
  };

  ctx.sym.bss = add("__bss_start", 0);
  ctx.sym.end1 = add("end", -1);
  ctx.sym.end2 = add("_end", -1);
  ctx.sym.etext1 = add("etext", -1);
  ctx.sym.etext2 = add("_etext", -1);
  ctx.sym.edata1 = add("edata", -1);
  ctx.sym.edata2 = add("_edata", -1);
}

static void demoteDefined(Defined &sym, DenseMap<SectionBase *, size_t> &map) {
  if (map.empty())
    for (auto [i, sec] : llvm::enumerate(sym.file->getSections()))
      map.try_emplace(sec, i);
  // Change WEAK to GLOBAL so that if a scanned relocation references sym,
  // maybeReportUndefined will report an error.
  uint8_t binding = sym.isWeak() ? uint8_t(STB_GLOBAL) : sym.binding;
  Undefined(sym.file, sym.getName(), binding, sym.stOther, sym.type,
            /*discardedSecIdx=*/map.lookup(sym.section))
      .overwrite(sym);
  // Eliminate from the symbol table, otherwise we would leave an undefined
  // symbol if the symbol is unreferenced in the absence of GC.
  sym.isUsedInRegularObj = false;
}

// If all references to a DSO happen to be weak, the DSO is not added to
// DT_NEEDED. If that happens, replace ShardSymbol with Undefined to avoid
// dangling references to an unneeded DSO. Use a weak binding to avoid
// --no-allow-shlib-undefined diagnostics. Similarly, demote lazy symbols.
//
// In addition, demote symbols defined in discarded sections, so that
// references to /DISCARD/ discarded symbols will lead to errors.
static void demoteSymbolsAndComputeIsPreemptible(Ctx &ctx) {
  llvm::TimeTraceScope timeScope("Demote symbols");
  DenseMap<InputFile *, DenseMap<SectionBase *, size_t>> sectionIndexMap;
  for (Symbol *sym : ctx.symtab->getSymbols()) {
    if (auto *d = dyn_cast<Defined>(sym)) {
      if (d->section && !d->section->isLive())
        demoteDefined(*d, sectionIndexMap[d->file]);
    } else {
      auto *s = dyn_cast<SharedSymbol>(sym);
      if (sym->isLazy() || (s && !cast<SharedFile>(s->file)->isNeeded)) {
        uint8_t binding = sym->isLazy() ? sym->binding : uint8_t(STB_WEAK);
        Undefined(ctx.internalFile, sym->getName(), binding, sym->stOther,
                  sym->type)
            .overwrite(*sym);
        sym->versionId = VER_NDX_GLOBAL;
      }
    }

    sym->isPreemptible = (sym->isUndefined() || sym->isExported) &&
                         computeIsPreemptible(ctx, *sym);
  }
}

static OutputSection *findSection(Ctx &ctx, StringRef name,
                                  unsigned partition = 1) {
  for (SectionCommand *cmd : ctx.script->sectionCommands)
    if (auto *osd = dyn_cast<OutputDesc>(cmd))
      if (osd->osec.name == name && osd->osec.partition == partition)
        return &osd->osec;
  return nullptr;
}

// The main function of the writer.
template <class ELFT> void Writer<ELFT>::run() {
  // Now that we have a complete set of output sections. This function
  // completes section contents. For example, we need to add strings
  // to the string table, and add entries to .got and .plt.
  // finalizeSections does that.
  finalizeSections();
  checkExecuteOnly();
  checkExecuteOnlyReport();

  // If --compressed-debug-sections is specified, compress .debug_* sections.
  // Do it right now because it changes the size of output sections.
  for (OutputSection *sec : ctx.outputSections)
    sec->maybeCompress<ELFT>(ctx);

  if (ctx.script->hasSectionsCommand)
    ctx.script->allocateHeaders(ctx.mainPart->phdrs);

  // Remove empty PT_LOAD to avoid causing the dynamic linker to try to mmap a
  // 0 sized region. This has to be done late since only after assignAddresses
  // we know the size of the sections.
  for (Partition &part : ctx.partitions)
    removeEmptyPTLoad(ctx, part.phdrs);

  if (!ctx.arg.oFormatBinary)
    assignFileOffsets();
  else
    assignFileOffsetsBinary();

  for (Partition &part : ctx.partitions)
    setPhdrs(part);

  // Handle --print-map(-M)/--Map and --cref. Dump them before checkSections()
  // because the files may be useful in case checkSections() or openFile()
  // fails, for example, due to an erroneous file size.
  writeMapAndCref(ctx);

  // Handle --print-memory-usage option.
  if (ctx.arg.printMemoryUsage)
    ctx.script->printMemoryUsage(ctx.e.outs());

  if (ctx.arg.checkSections)
    checkSections();

  // It does not make sense try to open the file if we have error already.
  if (errCount(ctx))
    return;

  {
    llvm::TimeTraceScope timeScope("Write output file");
    // Write the result down to a file.
    openFile();
    if (errCount(ctx))
      return;

    if (!ctx.arg.oFormatBinary) {
      if (ctx.arg.zSeparate != SeparateSegmentKind::None)
        writeTrapInstr();
      writeHeader();
      writeSections();
    } else {
      writeSectionsBinary();
    }

    // Backfill .note.gnu.build-id section content. This is done at last
    // because the content is usually a hash value of the entire output file.
    writeBuildId();
    if (errCount(ctx))
      return;

    if (!ctx.e.disableOutput) {
      if (auto e = buffer->commit())
        Err(ctx) << "failed to write output '" << buffer->getPath()
                 << "': " << std::move(e);
    }

    if (!ctx.arg.cmseOutputLib.empty())
      writeARMCmseImportLib<ELFT>(ctx);
  }
}

template <class ELFT, class RelTy>
static void markUsedLocalSymbolsImpl(ObjFile<ELFT> *file,
                                     llvm::ArrayRef<RelTy> rels) {
  for (const RelTy &rel : rels) {
    Symbol &sym = file->getRelocTargetSym(rel);
    if (sym.isLocal())
      sym.used = true;
  }
}

// The function ensures that the "used" field of local symbols reflects the fact
// that the symbol is used in a relocation from a live section.
template <class ELFT> static void markUsedLocalSymbols(Ctx &ctx) {
  // With --gc-sections, the field is already filled.
  // See MarkLive<ELFT>::resolveReloc().
  if (ctx.arg.gcSections)
    return;
  for (ELFFileBase *file : ctx.objectFiles) {
    ObjFile<ELFT> *f = cast<ObjFile<ELFT>>(file);
    for (InputSectionBase *s : f->getSections()) {
      InputSection *isec = dyn_cast_or_null<InputSection>(s);
      if (!isec)
        continue;
      if (isec->type == SHT_REL) {
        markUsedLocalSymbolsImpl(f, isec->getDataAs<typename ELFT::Rel>());
      } else if (isec->type == SHT_RELA) {
        markUsedLocalSymbolsImpl(f, isec->getDataAs<typename ELFT::Rela>());
      } else if (isec->type == SHT_CREL) {
        // The is64=true variant also works with ELF32 since only the r_symidx
        // member is used.
        for (Elf_Crel_Impl<true> r : RelocsCrel<true>(isec->content_)) {
          Symbol &sym = file->getSymbol(r.r_symidx);
          if (sym.isLocal())
            sym.used = true;
        }
      }
    }
  }
}

static bool shouldKeepInSymtab(Ctx &ctx, const Defined &sym) {
  if (sym.isSection())
    return false;

  // If --emit-reloc or -r is given, preserve symbols referenced by relocations
  // from live sections.
  if (sym.used && ctx.arg.copyRelocs)
    return true;

  // Exclude local symbols pointing to .ARM.exidx sections.
  // They are probably mapping symbols "$d", which are optional for these
  // sections. After merging the .ARM.exidx sections, some of these symbols
  // may become dangling. The easiest way to avoid the issue is not to add
  // them to the symbol table from the beginning.
  if (ctx.arg.emachine == EM_ARM && sym.section &&
      sym.section->type == SHT_ARM_EXIDX)
    return false;

  if (ctx.arg.discard == DiscardPolicy::None)
    return true;
  if (ctx.arg.discard == DiscardPolicy::All)
    return false;

  // In ELF assembly .L symbols are normally discarded by the assembler.
  // If the assembler fails to do so, the linker discards them if
  // * --discard-locals is used.
  // * The symbol is in a SHF_MERGE section, which is normally the reason for
  //   the assembler keeping the .L symbol.
  if (sym.getName().starts_with(".L") &&
      (ctx.arg.discard == DiscardPolicy::Locals ||
       (sym.section && (sym.section->flags & SHF_MERGE))))
    return false;
  return true;
}

bool elf::includeInSymtab(Ctx &ctx, const Symbol &b) {
  if (auto *d = dyn_cast<Defined>(&b)) {
    // Always include absolute symbols.
    SectionBase *sec = d->section;
    if (!sec)
      return true;
    assert(sec->isLive());

    if (auto *s = dyn_cast<MergeInputSection>(sec))
      return s->getSectionPiece(d->value).live;
    return true;
  }
  return b.used || !ctx.arg.gcSections;
}

// Scan local symbols to:
//
// - demote symbols defined relative to /DISCARD/ discarded input sections so
//   that relocations referencing them will lead to errors.
// - copy eligible symbols to .symTab
static void demoteAndCopyLocalSymbols(Ctx &ctx) {
  llvm::TimeTraceScope timeScope("Add local symbols");
  for (ELFFileBase *file : ctx.objectFiles) {
    DenseMap<SectionBase *, size_t> sectionIndexMap;
    for (Symbol *b : file->getLocalSymbols()) {
      assert(b->isLocal() && "should have been caught in initializeSymbols()");
      auto *dr = dyn_cast<Defined>(b);
      if (!dr)
        continue;

      if (dr->section && !dr->section->isLive())
        demoteDefined(*dr, sectionIndexMap);
      else if (ctx.in.symTab && includeInSymtab(ctx, *b) &&
               shouldKeepInSymtab(ctx, *dr))
        ctx.in.symTab->addSymbol(b);
    }
  }
}

// Create a section symbol for each output section so that we can represent
// relocations that point to the section. If we know that no relocation is
// referring to a section (that happens if the section is a synthetic one), we
// don't create a section symbol for that section.
template <class ELFT> void Writer<ELFT>::addSectionSymbols() {
  for (SectionCommand *cmd : ctx.script->sectionCommands) {
    auto *osd = dyn_cast<OutputDesc>(cmd);
    if (!osd)
      continue;
    OutputSection &osec = osd->osec;
    InputSectionBase *isec = nullptr;
    // Iterate over all input sections and add a STT_SECTION symbol if any input
    // section may be a relocation target.
    for (SectionCommand *cmd : osec.commands) {
      auto *isd = dyn_cast<InputSectionDescription>(cmd);
      if (!isd)
        continue;
      for (InputSectionBase *s : isd->sections) {
        // Relocations are not using REL[A] section symbols.
        if (isStaticRelSecType(s->type))
          continue;

        // Unlike other synthetic sections, mergeable output sections contain
        // data copied from input sections, and there may be a relocation
        // pointing to its contents if -r or --emit-reloc is given.
        if (isa<SyntheticSection>(s) && !(s->flags & SHF_MERGE))
          continue;

        isec = s;
        break;
      }
    }
    if (!isec)
      continue;

    // Set the symbol to be relative to the output section so that its st_value
    // equals the output section address. Note, there may be a gap between the
    // start of the output section and isec.
    ctx.in.symTab->addSymbol(makeDefined(ctx, isec->file, "", STB_LOCAL,
                                         /*stOther=*/0, STT_SECTION,
                                         /*value=*/0, /*size=*/0, &osec));
  }
}

// Returns true if this is a variant of .data.rel.ro.
static bool isRelRoDataSection(Ctx &ctx, StringRef secName) {
  if (!secName.consume_front(".data.rel.ro"))
    return false;
  if (secName.empty())
    return true;
  // If -z keep-data-section-prefix is specified, additionally allow
  // '.data.rel.ro.hot' and '.data.rel.ro.unlikely'.
  if (ctx.arg.zKeepDataSectionPrefix)
    return secName == ".hot" || secName == ".unlikely";
  return false;
}

// Today's loaders have a feature to make segments read-only after
// processing dynamic relocations to enhance security. PT_GNU_RELRO
// is defined for that.
//
// This function returns true if a section needs to be put into a
// PT_GNU_RELRO segment.
static bool isRelroSection(Ctx &ctx, const OutputSection *sec) {
  if (!ctx.arg.zRelro)
    return false;
  if (sec->relro)
    return true;

  uint64_t flags = sec->flags;

  // Non-allocatable or non-writable sections don't need RELRO because
  // they are not writable or not even mapped to memory in the first place.
  // RELRO is for sections that are essentially read-only but need to
  // be writable only at process startup to allow dynamic linker to
  // apply relocations.
  if (!(flags & SHF_ALLOC) || !(flags & SHF_WRITE))
    return false;

  // Once initialized, TLS data segments are used as data templates
  // for a thread-local storage. For each new thread, runtime
  // allocates memory for a TLS and copy templates there. No thread
  // are supposed to use templates directly. Thus, it can be in RELRO.
  if (flags & SHF_TLS)
    return true;

  // .init_array, .preinit_array and .fini_array contain pointers to
  // functions that are executed on process startup or exit. These
  // pointers are set by the static linker, and they are not expected
  // to change at runtime. But if you are an attacker, you could do
  // interesting things by manipulating pointers in .fini_array, for
  // example. So they are put into RELRO.
  uint32_t type = sec->type;
  if (type == SHT_INIT_ARRAY || type == SHT_FINI_ARRAY ||
      type == SHT_PREINIT_ARRAY)
    return true;

  // .got contains pointers to external symbols. They are resolved by
  // the dynamic linker when a module is loaded into memory, and after
  // that they are not expected to change. So, it can be in RELRO.
  if (ctx.in.got && sec == ctx.in.got->getParent())
    return true;

  // .toc is a GOT-ish section for PowerPC64. Their contents are accessed
  // through r2 register, which is reserved for that purpose. Since r2 is used
  // for accessing .got as well, .got and .toc need to be close enough in the
  // virtual address space. Usually, .toc comes just after .got. Since we place
  // .got into RELRO, .toc needs to be placed into RELRO too.
  if (sec->name == ".toc")
    return true;

  // .got.plt contains pointers to external function symbols. They are
  // by default resolved lazily, so we usually cannot put it into RELRO.
  // However, if "-z now" is given, the lazy symbol resolution is
  // disabled, which enables us to put it into RELRO.
  if (sec == ctx.in.gotPlt->getParent())
    return ctx.arg.zNow;

  if (ctx.in.relroPadding && sec == ctx.in.relroPadding->getParent())
    return true;

  // .dynamic section contains data for the dynamic linker, and
  // there's no need to write to it at runtime, so it's better to put
  // it into RELRO.
  if (sec->name == ".dynamic")
    return true;

  // Sections with some special names are put into RELRO. This is a
  // bit unfortunate because section names shouldn't be significant in
  // ELF in spirit. But in reality many linker features depend on
  // magic section names.
  StringRef s = sec->name;

  bool abiAgnostic = isRelRoDataSection(ctx, s) || s == ".bss.rel.ro" ||
                     s == ".ctors" || s == ".dtors" || s == ".jcr" ||
                     s == ".eh_frame" || s == ".fini_array" ||
                     s == ".init_array" || s == ".preinit_array";

  bool abiSpecific =
      ctx.arg.osabi == ELFOSABI_OPENBSD && s == ".openbsd.randomdata";

  return abiAgnostic || abiSpecific;
}

// We compute a rank for each section. The rank indicates where the
// section should be placed in the file.  Instead of using simple
// numbers (0,1,2...), we use a series of flags. One for each decision
// point when placing the section.
// Using flags has two key properties:
// * It is easy to check if a give branch was taken.
// * It is easy two see how similar two ranks are (see getRankProximity).
enum RankFlags {
  RF_NOT_ADDR_SET = 1 << 27,
  RF_NOT_ALLOC = 1 << 26,
  RF_PARTITION = 1 << 18, // Partition number (8 bits)
  RF_LARGE_EXEC_WRITE = 1 << 16,
  RF_LARGE_ALT = 1 << 15,
  RF_WRITE = 1 << 14,
  RF_EXEC_WRITE = 1 << 13,
  RF_EXEC = 1 << 12,
  RF_RODATA = 1 << 11,
  RF_LARGE_EXEC = 1 << 10,
  RF_LARGE = 1 << 9,
  RF_NOT_RELRO = 1 << 8,
  RF_NOT_TLS = 1 << 7,
  RF_BSS = 1 << 6,
};

unsigned elf::getSectionRank(Ctx &ctx, OutputSection &osec) {
  unsigned rank = osec.partition * RF_PARTITION;

  // We want to put section specified by -T option first, so we
  // can start assigning VA starting from them later.
  if (ctx.arg.sectionStartMap.count(osec.name))
    return rank;
  rank |= RF_NOT_ADDR_SET;

  // Allocatable sections go first to reduce the total PT_LOAD size and
  // so debug info doesn't change addresses in actual code.
  if (!(osec.flags & SHF_ALLOC))
    return rank | RF_NOT_ALLOC;

  // Sort sections based on their access permission in the following
  // order: R, RX, RXW, RW(RELRO), RW(non-RELRO).
  //
  // Read-only sections come first such that they go in the PT_LOAD covering the
  // program headers at the start of the file.
  //
  // The layout for writable sections is PT_LOAD(PT_GNU_RELRO(.data.rel.ro
  // .bss.rel.ro) | .data .bss), where | marks where page alignment happens.
  // An alternative ordering is PT_LOAD(.data | PT_GNU_RELRO( .data.rel.ro
  // .bss.rel.ro) | .bss), but it may waste more bytes due to 2 alignment
  // places.
  bool isExec = osec.flags & SHF_EXECINSTR;
  bool isWrite = osec.flags & SHF_WRITE;
  bool isLarge = osec.flags & SHF_X86_64_LARGE && ctx.arg.emachine == EM_X86_64;

  if (!isWrite && !isExec) {
    // Among PROGBITS sections, place .lrodata further from .text.
    // For -z lrodata-after-bss, place .lrodata after .lbss like GNU ld. This
    // layout has one extra PT_LOAD, but alleviates relocation overflow
    // pressure for absolute relocations referencing small data from -fno-pic
    // relocatable files.
    if (isLarge)
      rank |= ctx.arg.zLrodataAfterBss ? RF_LARGE_ALT : 0;
    else
      rank |= ctx.arg.zLrodataAfterBss ? 0 : RF_LARGE;

    if (osec.type == SHT_LLVM_PART_EHDR)
      ;
    else if (osec.type == SHT_LLVM_PART_PHDR)
      rank |= 1;
    else if (osec.name == ".interp")
      rank |= 2;
    // Put .note sections at the beginning so that they are likely to be
    // included in a truncate core file. In particular, .note.gnu.build-id, if
    // available, can identify the object file.
    else if (osec.type == SHT_NOTE)
      rank |= 3;
    // Make PROGBITS sections (e.g .rodata .eh_frame) closer to .text to
    // alleviate relocation overflow pressure. Large special sections such as
    // .dynstr and .dynsym can be away from .text.
    else if (osec.type != SHT_PROGBITS)
      rank |= 4;
    else
      rank |= RF_RODATA;
  } else if (isExec) {
    // Place readonly .ltext before .lrodata and writable .ltext after .lbss to
    // keep writable and readonly segments separate.
    if (isLarge) {
      rank |= isWrite ? RF_LARGE_EXEC_WRITE : RF_LARGE_EXEC;
    } else {
      rank |= isWrite ? RF_EXEC_WRITE : RF_EXEC;
    }
  } else {
    rank |= RF_WRITE;
    // The TLS initialization block needs to be a single contiguous block. Place
    // TLS sections directly before the other RELRO sections.
    if (!(osec.flags & SHF_TLS))
      rank |= RF_NOT_TLS;
    if (isRelroSection(ctx, &osec))
      osec.relro = true;
    else
      rank |= RF_NOT_RELRO;
    // Place .ldata and .lbss after .bss. Making .bss closer to .text
    // alleviates relocation overflow pressure.
    // For -z lrodata-after-bss, place .lbss/.lrodata/.ldata after .bss.
    // .bss/.lbss being adjacent reuses the NOBITS size optimization.
    if (isLarge) {
      rank |= ctx.arg.zLrodataAfterBss
                  ? (osec.type == SHT_NOBITS ? 1 : RF_LARGE_ALT)
                  : RF_LARGE;
    }
  }

  // Within TLS sections, or within other RelRo sections, or within non-RelRo
  // sections, place non-NOBITS sections first.
  if (osec.type == SHT_NOBITS)
    rank |= RF_BSS;

  // Some architectures have additional ordering restrictions for sections
  // within the same PT_LOAD.
  if (ctx.arg.emachine == EM_PPC64) {
    // PPC64 has a number of special SHT_PROGBITS+SHF_ALLOC+SHF_WRITE sections
    // that we would like to make sure appear is a specific order to maximize
    // their coverage by a single signed 16-bit offset from the TOC base
    // pointer.
    StringRef name = osec.name;
    if (name == ".got")
      rank |= 1;
    else if (name == ".toc")
      rank |= 2;
  }

  if (ctx.arg.emachine == EM_MIPS) {
    if (osec.name != ".got")
      rank |= 1;
    // All sections with SHF_MIPS_GPREL flag should be grouped together
    // because data in these sections is addressable with a gp relative address.
    if (osec.flags & SHF_MIPS_GPREL)
      rank |= 2;
  }

  if (ctx.arg.emachine == EM_RISCV) {
    // .sdata and .sbss are placed closer to make GP relaxation more profitable
    // and match GNU ld.
    StringRef name = osec.name;
    if (name == ".sdata" || (osec.type == SHT_NOBITS && name != ".sbss"))
      rank |= 1;
  }

  return rank;
}

static bool compareSections(Ctx &ctx, const SectionCommand *aCmd,
                            const SectionCommand *bCmd) {
  const OutputSection *a = &cast<OutputDesc>(aCmd)->osec;
  const OutputSection *b = &cast<OutputDesc>(bCmd)->osec;

  if (a->sortRank != b->sortRank)
    return a->sortRank < b->sortRank;

  if (!(a->sortRank & RF_NOT_ADDR_SET))
    return ctx.arg.sectionStartMap.lookup(a->name) <
           ctx.arg.sectionStartMap.lookup(b->name);
  return false;
}

void PhdrEntry::add(OutputSection *sec) {
  lastSec = sec;
  if (!firstSec)
    firstSec = sec;
  p_align = std::max(p_align, sec->addralign);
  if (p_type == PT_LOAD)
    sec->ptLoad = this;
}

// A statically linked position-dependent executable should only contain
// IRELATIVE relocations and no other dynamic relocations. Encapsulation symbols
// __rel[a]_iplt_{start,end} will be defined for .rel[a].dyn, to be
// processed by the libc runtime. Other executables or DSOs use dynamic tags
// instead.
template <class ELFT> void Writer<ELFT>::addRelIpltSymbols() {
  if (ctx.arg.isPic)
    return;

  // __rela_iplt_{start,end} are initially defined relative to dummy section 0.
  // We'll override ctx.out.elfHeader with relaDyn later when we are sure that
  // .rela.dyn will be present in the output.
  std::string name = ctx.arg.isRela ? "__rela_iplt_start" : "__rel_iplt_start";
  ctx.sym.relaIpltStart =
      addOptionalRegular(ctx, name, ctx.out.elfHeader.get(), 0, STV_HIDDEN);
  name.replace(name.size() - 5, 5, "end");
  ctx.sym.relaIpltEnd =
      addOptionalRegular(ctx, name, ctx.out.elfHeader.get(), 0, STV_HIDDEN);
}

// This function generates assignments for predefined symbols (e.g. _end or
// _etext) and inserts them into the commands sequence to be processed at the
// appropriate time. This ensures that the value is going to be correct by the
// time any references to these symbols are processed and is equivalent to
// defining these symbols explicitly in the linker script.
template <class ELFT> void Writer<ELFT>::setReservedSymbolSections() {
  if (ctx.sym.globalOffsetTable) {
    // The _GLOBAL_OFFSET_TABLE_ symbol is defined by target convention usually
    // to the start of the .got or .got.plt section.
    InputSection *sec = ctx.in.gotPlt.get();
    if (!ctx.target->gotBaseSymInGotPlt)
      sec = ctx.in.mipsGot ? cast<InputSection>(ctx.in.mipsGot.get())
                           : cast<InputSection>(ctx.in.got.get());
    ctx.sym.globalOffsetTable->section = sec;
  }

  // .rela_iplt_{start,end} mark the start and the end of the section containing
  // IRELATIVE relocations.
  if (ctx.sym.relaIpltStart) {
    auto &dyn = getIRelativeSection(ctx);
    if (dyn.isNeeded()) {
      ctx.sym.relaIpltStart->section = &dyn;
      ctx.sym.relaIpltEnd->section = &dyn;
      ctx.sym.relaIpltEnd->value = dyn.getSize();
    }
  }

  PhdrEntry *last = nullptr;
  OutputSection *lastRO = nullptr;
  auto isLarge = [&ctx = ctx](OutputSection *osec) {
    return ctx.arg.emachine == EM_X86_64 && osec->flags & SHF_X86_64_LARGE;
  };
  for (Partition &part : ctx.partitions) {
    for (auto &p : part.phdrs) {
      if (p->p_type != PT_LOAD)
        continue;
      last = p.get();
      if (!(p->p_flags & PF_W) && p->lastSec && !isLarge(p->lastSec))
        lastRO = p->lastSec;
    }
  }

  if (lastRO) {
    // _etext is the first location after the last read-only loadable segment
    // that does not contain large sections.
    if (ctx.sym.etext1)
      ctx.sym.etext1->section = lastRO;
    if (ctx.sym.etext2)
      ctx.sym.etext2->section = lastRO;
  }

  if (last) {
    // _edata points to the end of the last non-large mapped initialized
    // section.
    OutputSection *edata = nullptr;
    for (OutputSection *os : ctx.outputSections) {
      if (os->type != SHT_NOBITS && !isLarge(os))
        edata = os;
      if (os == last->lastSec)
        break;
    }

    if (ctx.sym.edata1)
      ctx.sym.edata1->section = edata;
    if (ctx.sym.edata2)
      ctx.sym.edata2->section = edata;

    // _end is the first location after the uninitialized data region.
    if (ctx.sym.end1)
      ctx.sym.end1->section = last->lastSec;
    if (ctx.sym.end2)
      ctx.sym.end2->section = last->lastSec;
  }

  if (ctx.sym.bss) {
    // On RISC-V, set __bss_start to the start of .sbss if present.
    OutputSection *sbss =
        ctx.arg.emachine == EM_RISCV ? findSection(ctx, ".sbss") : nullptr;
    ctx.sym.bss->section = sbss ? sbss : findSection(ctx, ".bss");
  }

  // Setup MIPS _gp_disp/__gnu_local_gp symbols which should
  // be equal to the _gp symbol's value.
  if (ctx.sym.mipsGp) {
    // Find GP-relative section with the lowest address
    // and use this address to calculate default _gp value.
    for (OutputSection *os : ctx.outputSections) {
      if (os->flags & SHF_MIPS_GPREL) {
        ctx.sym.mipsGp->section = os;
        ctx.sym.mipsGp->value = 0x7ff0;
        break;
      }
    }
  }
}

// We want to find how similar two ranks are.
// The more branches in getSectionRank that match, the more similar they are.
// Since each branch corresponds to a bit flag, we can just use
// countLeadingZeros.
static int getRankProximity(OutputSection *a, SectionCommand *b) {
  auto *osd = dyn_cast<OutputDesc>(b);
  return (osd && osd->osec.hasInputSections)
             ? llvm::countl_zero(a->sortRank ^ osd->osec.sortRank)
             : -1;
}

// When placing orphan sections, we want to place them after symbol assignments
// so that an orphan after
//   begin_foo = .;
//   foo : { *(foo) }
//   end_foo = .;
// doesn't break the intended meaning of the begin/end symbols.
// We don't want to go over sections since findOrphanPos is the
// one in charge of deciding the order of the sections.
// We don't want to go over changes to '.', since doing so in
//  rx_sec : { *(rx_sec) }
//  . = ALIGN(0x1000);
//  /* The RW PT_LOAD starts here*/
//  rw_sec : { *(rw_sec) }
// would mean that the RW PT_LOAD would become unaligned.
static bool shouldSkip(SectionCommand *cmd) {
  if (auto *assign = dyn_cast<SymbolAssignment>(cmd))
    return assign->name != ".";
  return false;
}

// We want to place orphan sections so that they share as much
// characteristics with their neighbors as possible. For example, if
// both are rw, or both are tls.
static SmallVectorImpl<SectionCommand *>::iterator
findOrphanPos(Ctx &ctx, SmallVectorImpl<SectionCommand *>::iterator b,
              SmallVectorImpl<SectionCommand *>::iterator e) {
  // Place non-alloc orphan sections at the end. This matches how we assign file
  // offsets to non-alloc sections.
  OutputSection *sec = &cast<OutputDesc>(*e)->osec;
  if (!(sec->flags & SHF_ALLOC))
    return e;

  // As a special case, place .relro_padding before the SymbolAssignment using
  // DATA_SEGMENT_RELRO_END, if present.
  if (ctx.in.relroPadding && sec == ctx.in.relroPadding->getParent()) {
    auto i = std::find_if(b, e, [=](SectionCommand *a) {
      if (auto *assign = dyn_cast<SymbolAssignment>(a))
        return assign->dataSegmentRelroEnd;
      return false;
    });
    if (i != e)
      return i;
  }

  // Find the most similar output section as the anchor. Rank Proximity is a
  // value in the range [-1, 32] where [0, 32] indicates potential anchors (0:
  // least similar; 32: identical). -1 means not an anchor.
  //
  // In the event of proximity ties, we select the first or last section
  // depending on whether the orphan's rank is smaller.
  int maxP = 0;
  auto i = e;
  for (auto j = b; j != e; ++j) {
    int p = getRankProximity(sec, *j);
    if (p > maxP ||
        (p == maxP && cast<OutputDesc>(*j)->osec.sortRank <= sec->sortRank)) {
      maxP = p;
      i = j;
    }
  }
  if (i == e)
    return e;

  auto isOutputSecWithInputSections = [](SectionCommand *cmd) {
    auto *osd = dyn_cast<OutputDesc>(cmd);
    return osd && osd->osec.hasInputSections;
  };

  // Then, scan backward or forward through the script for a suitable insertion
  // point. If i's rank is larger, the orphan section can be placed before i.
  //
  // However, don't do this if custom program headers are defined. Otherwise,
  // adding the orphan to a previous segment can change its flags, for example,
  // making a read-only segment writable. If memory regions are defined, an
  // orphan section should continue the same region as the found section to
  // better resemble the behavior of GNU ld.
  bool mustAfter =
      ctx.script->hasPhdrsCommands() || !ctx.script->memoryRegions.empty();
  if (cast<OutputDesc>(*i)->osec.sortRank <= sec->sortRank || mustAfter) {
    for (auto j = ++i; j != e; ++j) {
      if (!isOutputSecWithInputSections(*j))
        continue;
      if (getRankProximity(sec, *j) != maxP)
        break;
      i = j + 1;
    }
  } else {
    for (; i != b; --i)
      if (isOutputSecWithInputSections(i[-1]))
        break;
  }

  // As a special case, if the orphan section is the last section, put
  // it at the very end, past any other commands.
  // This matches bfd's behavior and is convenient when the linker script fully
  // specifies the start of the file, but doesn't care about the end (the non
  // alloc sections for example).
  if (std::none_of(i, e, isOutputSecWithInputSections))
    return e;

  while (i != e && shouldSkip(*i))
    ++i;
  return i;
}

// Adds random priorities to sections not already in the map.
static void maybeShuffle(Ctx &ctx,
                         DenseMap<const InputSectionBase *, int> &order) {
  if (ctx.arg.shuffleSections.empty())
    return;

  SmallVector<InputSectionBase *, 0> matched, sections = ctx.inputSections;
  matched.reserve(sections.size());
  for (const auto &patAndSeed : ctx.arg.shuffleSections) {
    matched.clear();
    for (InputSectionBase *sec : sections)
      if (patAndSeed.first.match(sec->name))
        matched.push_back(sec);
    const uint32_t seed = patAndSeed.second;
    if (seed == UINT32_MAX) {
      // If --shuffle-sections <section-glob>=-1, reverse the section order. The
      // section order is stable even if the number of sections changes. This is
      // useful to catch issues like static initialization order fiasco
      // reliably.
      std::reverse(matched.begin(), matched.end());
    } else {
      std::mt19937 g(seed ? seed : std::random_device()());
      llvm::shuffle(matched.begin(), matched.end(), g);
    }
    size_t i = 0;
    for (InputSectionBase *&sec : sections)
      if (patAndSeed.first.match(sec->name))
        sec = matched[i++];
  }

  // Existing priorities are < 0, so use priorities >= 0 for the missing
  // sections.
  int prio = 0;
  for (InputSectionBase *sec : sections) {
    if (order.try_emplace(sec, prio).second)
      ++prio;
  }
}

// Return section order within an InputSectionDescription.
// If both --symbol-ordering-file and call graph profile are present, the order
// file takes precedence, but the call graph profile is still used for symbols
// that don't appear in the order file.
static DenseMap<const InputSectionBase *, int> buildSectionOrder(Ctx &ctx) {
  DenseMap<const InputSectionBase *, int> sectionOrder;
  if (ctx.arg.bpStartupFunctionSort || ctx.arg.bpFunctionOrderForCompression ||
      ctx.arg.bpDataOrderForCompression) {
    TimeTraceScope timeScope("Balanced Partitioning Section Orderer");
    sectionOrder = runBalancedPartitioning(
        ctx, ctx.arg.bpStartupFunctionSort ? ctx.arg.irpgoProfilePath : "",
        ctx.arg.bpFunctionOrderForCompression,
        ctx.arg.bpDataOrderForCompression,
        ctx.arg.bpCompressionSortStartupFunctions,
        ctx.arg.bpVerboseSectionOrderer);
  } else if (!ctx.arg.callGraphProfile.empty()) {
    sectionOrder = computeCallGraphProfileOrder(ctx);
  }

  if (ctx.arg.symbolOrderingFile.empty())
    return sectionOrder;

  struct SymbolOrderEntry {
    int priority;
    bool present;
  };

  // Build a map from symbols to their priorities. Symbols that didn't
  // appear in the symbol ordering file have the lowest priority 0.
  // All explicitly mentioned symbols have negative (higher) priorities.
  DenseMap<CachedHashStringRef, SymbolOrderEntry> symbolOrder;
  int priority = -sectionOrder.size() - ctx.arg.symbolOrderingFile.size();
  for (StringRef s : ctx.arg.symbolOrderingFile)
    symbolOrder.insert({CachedHashStringRef(s), {priority++, false}});

  // Build a map from sections to their priorities.
  auto addSym = [&](Symbol &sym) {
    auto it = symbolOrder.find(CachedHashStringRef(sym.getName()));
    if (it == symbolOrder.end())
      return;
    SymbolOrderEntry &ent = it->second;
    ent.present = true;

    maybeWarnUnorderableSymbol(ctx, &sym);

    if (auto *d = dyn_cast<Defined>(&sym)) {
      if (auto *sec = dyn_cast_or_null<InputSectionBase>(d->section)) {
        int &priority = sectionOrder[cast<InputSectionBase>(sec)];
        priority = std::min(priority, ent.priority);
      }
    }
  };

  // We want both global and local symbols. We get the global ones from the
  // symbol table and iterate the object files for the local ones.
  for (Symbol *sym : ctx.symtab->getSymbols())
    addSym(*sym);

  for (ELFFileBase *file : ctx.objectFiles)
    for (Symbol *sym : file->getLocalSymbols())
      addSym(*sym);

  if (ctx.arg.warnSymbolOrdering)
    for (auto orderEntry : symbolOrder)
      if (!orderEntry.second.present)
        Warn(ctx) << "symbol ordering file: no such symbol: "
                  << orderEntry.first.val();

  return sectionOrder;
}

// Sorts the sections in ISD according to the provided section order.
static void
sortISDBySectionOrder(Ctx &ctx, InputSectionDescription *isd,
                      const DenseMap<const InputSectionBase *, int> &order,
                      bool executableOutputSection) {
  SmallVector<InputSection *, 0> unorderedSections;
  SmallVector<std::pair<InputSection *, int>, 0> orderedSections;
  uint64_t unorderedSize = 0;
  uint64_t totalSize = 0;

  for (InputSection *isec : isd->sections) {
    if (executableOutputSection)
      totalSize += isec->getSize();
    auto i = order.find(isec);
    if (i == order.end()) {
      unorderedSections.push_back(isec);
      unorderedSize += isec->getSize();
      continue;
    }
    orderedSections.push_back({isec, i->second});
  }
  llvm::sort(orderedSections, llvm::less_second());

  // Find an insertion point for the ordered section list in the unordered
  // section list. On targets with limited-range branches, this is the mid-point
  // of the unordered section list. This decreases the likelihood that a range
  // extension thunk will be needed to enter or exit the ordered region. If the
  // ordered section list is a list of hot functions, we can generally expect
  // the ordered functions to be called more often than the unordered functions,
  // making it more likely that any particular call will be within range, and
  // therefore reducing the number of thunks required.
  //
  // For example, imagine that you have 8MB of hot code and 32MB of cold code.
  // If the layout is:
  //
  // 8MB hot
  // 32MB cold
  //
  // only the first 8-16MB of the cold code (depending on which hot function it
  // is actually calling) can call the hot code without a range extension thunk.
  // However, if we use this layout:
  //
  // 16MB cold
  // 8MB hot
  // 16MB cold
  //
  // both the last 8-16MB of the first block of cold code and the first 8-16MB
  // of the second block of cold code can call the hot code without a thunk. So
  // we effectively double the amount of code that could potentially call into
  // the hot code without a thunk.
  //
  // The above is not necessary if total size of input sections in this "isd"
  // is small. Note that we assume all input sections are executable if the
  // output section is executable (which is not always true but supposed to
  // cover most cases).
  size_t insPt = 0;
  if (executableOutputSection && !orderedSections.empty() &&
      ctx.target->getThunkSectionSpacing() &&
      totalSize >= ctx.target->getThunkSectionSpacing()) {
    uint64_t unorderedPos = 0;
    for (; insPt != unorderedSections.size(); ++insPt) {
      unorderedPos += unorderedSections[insPt]->getSize();
      if (unorderedPos > unorderedSize / 2)
        break;
    }
  }

  isd->sections.clear();
  for (InputSection *isec : ArrayRef(unorderedSections).slice(0, insPt))
    isd->sections.push_back(isec);
  for (std::pair<InputSection *, int> p : orderedSections)
    isd->sections.push_back(p.first);
  for (InputSection *isec : ArrayRef(unorderedSections).slice(insPt))
    isd->sections.push_back(isec);
}

static void sortSection(Ctx &ctx, OutputSection &osec,
                        const DenseMap<const InputSectionBase *, int> &order) {
  StringRef name = osec.name;

  // Never sort these.
  if (name == ".init" || name == ".fini")
    return;

  // Sort input sections by priority using the list provided by
  // --symbol-ordering-file or --shuffle-sections=. This is a least significant
  // digit radix sort. The sections may be sorted stably again by a more
  // significant key.
  if (!order.empty())
    for (SectionCommand *b : osec.commands)
      if (auto *isd = dyn_cast<InputSectionDescription>(b))
        sortISDBySectionOrder(ctx, isd, order, osec.flags & SHF_EXECINSTR);

  if (ctx.script->hasSectionsCommand)
    return;

  if (name == ".init_array" || name == ".fini_array") {
    osec.sortInitFini();
  } else if (name == ".ctors" || name == ".dtors") {
    osec.sortCtorsDtors();
  } else if (ctx.arg.emachine == EM_PPC64 && name == ".toc") {
    // .toc is allocated just after .got and is accessed using GOT-relative
    // relocations. Object files compiled with small code model have an
    // addressable range of [.got, .got + 0xFFFC] for GOT-relative relocations.
    // To reduce the risk of relocation overflow, .toc contents are sorted so
    // that sections having smaller relocation offsets are at beginning of .toc
    assert(osec.commands.size() == 1);
    auto *isd = cast<InputSectionDescription>(osec.commands[0]);
    llvm::stable_sort(isd->sections,
                      [](const InputSection *a, const InputSection *b) -> bool {
                        return a->file->ppc64SmallCodeModelTocRelocs &&
                               !b->file->ppc64SmallCodeModelTocRelocs;
                      });
  }
}

// Sort sections within each InputSectionDescription.
template <class ELFT> void Writer<ELFT>::sortInputSections() {
  // Assign negative priorities.
  DenseMap<const InputSectionBase *, int> order = buildSectionOrder(ctx);
  // Assign non-negative priorities due to --shuffle-sections.
  maybeShuffle(ctx, order);
  for (SectionCommand *cmd : ctx.script->sectionCommands)
    if (auto *osd = dyn_cast<OutputDesc>(cmd))
      sortSection(ctx, osd->osec, order);
}

template <class ELFT> void Writer<ELFT>::sortSections() {
  llvm::TimeTraceScope timeScope("Sort sections");

  // Don't sort if using -r. It is not necessary and we want to preserve the
  // relative order for SHF_LINK_ORDER sections.
  if (ctx.arg.relocatable) {
    ctx.script->adjustOutputSections();
    return;
  }

  sortInputSections();

  for (SectionCommand *cmd : ctx.script->sectionCommands)
    if (auto *osd = dyn_cast<OutputDesc>(cmd))
      osd->osec.sortRank = getSectionRank(ctx, osd->osec);
  if (!ctx.script->hasSectionsCommand) {
    // OutputDescs are mostly contiguous, but may be interleaved with
    // SymbolAssignments in the presence of INSERT commands.
    auto mid = std::stable_partition(
        ctx.script->sectionCommands.begin(), ctx.script->sectionCommands.end(),
        [](SectionCommand *cmd) { return isa<OutputDesc>(cmd); });
    std::stable_sort(
        ctx.script->sectionCommands.begin(), mid,
        [&ctx = ctx](auto *l, auto *r) { return compareSections(ctx, l, r); });
  }

  // Process INSERT commands and update output section attributes. From this
  // point onwards the order of script->sectionCommands is fixed.
  ctx.script->processInsertCommands();
  ctx.script->adjustOutputSections();

  if (ctx.script->hasSectionsCommand)
    sortOrphanSections();

  ctx.script->adjustSectionsAfterSorting();
}

template <class ELFT> void Writer<ELFT>::sortOrphanSections() {
  // Orphan sections are sections present in the input files which are
  // not explicitly placed into the output file by the linker script.
  //
  // The sections in the linker script are already in the correct
  // order. We have to figuere out where to insert the orphan
  // sections.
  //
  // The order of the sections in the script is arbitrary and may not agree with
  // compareSections. This means that we cannot easily define a strict weak
  // ordering. To see why, consider a comparison of a section in the script and
  // one not in the script. We have a two simple options:
  // * Make them equivalent (a is not less than b, and b is not less than a).
  //   The problem is then that equivalence has to be transitive and we can
  //   have sections a, b and c with only b in a script and a less than c
  //   which breaks this property.
  // * Use compareSectionsNonScript. Given that the script order doesn't have
  //   to match, we can end up with sections a, b, c, d where b and c are in the
  //   script and c is compareSectionsNonScript less than b. In which case d
  //   can be equivalent to c, a to b and d < a. As a concrete example:
  //   .a (rx) # not in script
  //   .b (rx) # in script
  //   .c (ro) # in script
  //   .d (ro) # not in script
  //
  // The way we define an order then is:
  // *  Sort only the orphan sections. They are in the end right now.
  // *  Move each orphan section to its preferred position. We try
  //    to put each section in the last position where it can share
  //    a PT_LOAD.
  //
  // There is some ambiguity as to where exactly a new entry should be
  // inserted, because Commands contains not only output section
  // commands but also other types of commands such as symbol assignment
  // expressions. There's no correct answer here due to the lack of the
  // formal specification of the linker script. We use heuristics to
  // determine whether a new output command should be added before or
  // after another commands. For the details, look at shouldSkip
  // function.

  auto i = ctx.script->sectionCommands.begin();
  auto e = ctx.script->sectionCommands.end();
  auto nonScriptI = std::find_if(i, e, [](SectionCommand *cmd) {
    if (auto *osd = dyn_cast<OutputDesc>(cmd))
      return osd->osec.sectionIndex == UINT32_MAX;
    return false;
  });

  // Sort the orphan sections.
  std::stable_sort(nonScriptI, e, [&ctx = ctx](auto *l, auto *r) {
    return compareSections(ctx, l, r);
  });

  // As a horrible special case, skip the first . assignment if it is before any
  // section. We do this because it is common to set a load address by starting
  // the script with ". = 0xabcd" and the expectation is that every section is
  // after that.
  auto firstSectionOrDotAssignment =
      std::find_if(i, e, [](SectionCommand *cmd) { return !shouldSkip(cmd); });
  if (firstSectionOrDotAssignment != e &&
      isa<SymbolAssignment>(**firstSectionOrDotAssignment))
    ++firstSectionOrDotAssignment;
  i = firstSectionOrDotAssignment;

  while (nonScriptI != e) {
    auto pos = findOrphanPos(ctx, i, nonScriptI);
    OutputSection *orphan = &cast<OutputDesc>(*nonScriptI)->osec;

    // As an optimization, find all sections with the same sort rank
    // and insert them with one rotate.
    unsigned rank = orphan->sortRank;
    auto end = std::find_if(nonScriptI + 1, e, [=](SectionCommand *cmd) {
      return cast<OutputDesc>(cmd)->osec.sortRank != rank;
    });
    std::rotate(pos, nonScriptI, end);
    nonScriptI = end;
  }
}

static bool compareByFilePosition(InputSection *a, InputSection *b) {
  InputSection *la = a->flags & SHF_LINK_ORDER ? a->getLinkOrderDep() : nullptr;
  InputSection *lb = b->flags & SHF_LINK_ORDER ? b->getLinkOrderDep() : nullptr;
  // SHF_LINK_ORDER sections with non-zero sh_link are ordered before
  // non-SHF_LINK_ORDER sections and SHF_LINK_ORDER sections with zero sh_link.
  if (!la || !lb)
    return la && !lb;
  OutputSection *aOut = la->getParent();
  OutputSection *bOut = lb->getParent();

  if (aOut == bOut)
    return la->outSecOff < lb->outSecOff;
  if (aOut->addr == bOut->addr)
    return aOut->sectionIndex < bOut->sectionIndex;
  return aOut->addr < bOut->addr;
}

template <class ELFT> void Writer<ELFT>::resolveShfLinkOrder() {
  llvm::TimeTraceScope timeScope("Resolve SHF_LINK_ORDER");
  for (OutputSection *sec : ctx.outputSections) {
    if (!(sec->flags & SHF_LINK_ORDER))
      continue;

    // The ARM.exidx section use SHF_LINK_ORDER, but we have consolidated
    // this processing inside the ARMExidxsyntheticsection::finalizeContents().
    if (!ctx.arg.relocatable && ctx.arg.emachine == EM_ARM &&
        sec->type == SHT_ARM_EXIDX)
      continue;

    // Link order may be distributed across several InputSectionDescriptions.
    // Sorting is performed separately.
    SmallVector<InputSection **, 0> scriptSections;
    SmallVector<InputSection *, 0> sections;
    for (SectionCommand *cmd : sec->commands) {
      auto *isd = dyn_cast<InputSectionDescription>(cmd);
      if (!isd)
        continue;
      bool hasLinkOrder = false;
      scriptSections.clear();
      sections.clear();
      for (InputSection *&isec : isd->sections) {
        if (isec->flags & SHF_LINK_ORDER) {
          InputSection *link = isec->getLinkOrderDep();
          if (link && !link->getParent())
            ErrAlways(ctx) << isec << ": sh_link points to discarded section "
                           << link;
          hasLinkOrder = true;
        }
        scriptSections.push_back(&isec);
        sections.push_back(isec);
      }
      if (hasLinkOrder && errCount(ctx) == 0) {
        llvm::stable_sort(sections, compareByFilePosition);
        for (int i = 0, n = sections.size(); i != n; ++i)
          *scriptSections[i] = sections[i];
      }
    }
  }
}

static void finalizeSynthetic(Ctx &ctx, SyntheticSection *sec) {
  if (sec && sec->isNeeded() && sec->getParent()) {
    llvm::TimeTraceScope timeScope("Finalize synthetic sections", sec->name);
    sec->finalizeContents();
  }
}

static bool canInsertPadding(OutputSection *sec) {
  StringRef s = sec->name;
  return s == ".bss" || s == ".data" || s == ".data.rel.ro" || s == ".lbss" ||
         s == ".ldata" || s == ".lrodata" || s == ".ltext" || s == ".rodata" ||
         s.starts_with(".text");
}

static void randomizeSectionPadding(Ctx &ctx) {
  std::mt19937 g(*ctx.arg.randomizeSectionPadding);
  PhdrEntry *curPtLoad = nullptr;
  for (OutputSection *os : ctx.outputSections) {
    if (!canInsertPadding(os))
      continue;
    for (SectionCommand *bc : os->commands) {
      if (auto *isd = dyn_cast<InputSectionDescription>(bc)) {
        SmallVector<InputSection *, 0> tmp;
        if (os->ptLoad != curPtLoad) {
          tmp.push_back(make<RandomizePaddingSection>(
              ctx, g() % ctx.arg.maxPageSize, os));
          curPtLoad = os->ptLoad;
        }
        for (InputSection *isec : isd->sections) {
          // Probability of inserting padding is 1 in 16.
          if (g() % 16 == 0)
            tmp.push_back(
                make<RandomizePaddingSection>(ctx, isec->addralign, os));
          tmp.push_back(isec);
        }
        isd->sections = std::move(tmp);
      }
    }
  }
}

// We need to generate and finalize the content that depends on the address of
// InputSections. As the generation of the content may also alter InputSection
// addresses we must converge to a fixed point. We do that here. See the comment
// in Writer<ELFT>::finalizeSections().
template <class ELFT> void Writer<ELFT>::finalizeAddressDependentContent() {
  llvm::TimeTraceScope timeScope("Finalize address dependent content");
  AArch64Err843419Patcher a64p(ctx);
  ARMErr657417Patcher a32p(ctx);
  ctx.script->assignAddresses();

  // .ARM.exidx and SHF_LINK_ORDER do not require precise addresses, but they
  // do require the relative addresses of OutputSections because linker scripts
  // can assign Virtual Addresses to OutputSections that are not monotonically
  // increasing. Anything here must be repeatable, since spilling may change
  // section order.
  const auto finalizeOrderDependentContent = [this] {
    for (Partition &part : ctx.partitions)
      finalizeSynthetic(ctx, part.armExidx.get());
    resolveShfLinkOrder();
  };
  finalizeOrderDependentContent();

  // Converts call x@GDPLT to call __tls_get_addr
  if (ctx.arg.emachine == EM_HEXAGON)
    hexagonTLSSymbolUpdate(ctx);

  if (ctx.arg.randomizeSectionPadding)
    randomizeSectionPadding(ctx);

  uint32_t pass = 0, assignPasses = 0;
  for (;;) {
    bool changed = ctx.target->needsThunks
                       ? tc.createThunks(pass, ctx.outputSections)
                       : ctx.target->relaxOnce(pass);
    bool spilled = ctx.script->spillSections();
    changed |= spilled;
    ++pass;

    // With Thunk Size much smaller than branch range we expect to
    // converge quickly; if we get to 30 something has gone wrong.
    if (changed && pass >= 30) {
      Err(ctx) << "address assignment did not converge";
      break;
    }

    if (ctx.arg.fixCortexA53Errata843419) {
      if (changed)
        ctx.script->assignAddresses();
      changed |= a64p.createFixes();
    }
    if (ctx.arg.fixCortexA8) {
      if (changed)
        ctx.script->assignAddresses();
      changed |= a32p.createFixes();
    }

    finalizeSynthetic(ctx, ctx.in.got.get());
    if (ctx.in.mipsGot)
      ctx.in.mipsGot->updateAllocSize(ctx);

    for (Partition &part : ctx.partitions) {
      // The R_AARCH64_AUTH_RELATIVE has a smaller addend field as bits [63:32]
      // encode the signing schema. We've put relocations in .relr.auth.dyn
      // during RelocationScanner::processAux, but the target VA for some of
      // them might be wider than 32 bits. We can only know the final VA at this
      // point, so move relocations with large values from .relr.auth.dyn to
      // .rela.dyn. See also AArch64::relocate.
      if (part.relrAuthDyn) {
        auto it = llvm::remove_if(
            part.relrAuthDyn->relocs, [this, &part](const RelativeReloc &elem) {
              const Relocation &reloc = elem.inputSec->relocs()[elem.relocIdx];
              if (isInt<32>(reloc.sym->getVA(ctx, reloc.addend)))
                return false;
              part.relaDyn->addReloc({R_AARCH64_AUTH_RELATIVE, elem.inputSec,
                                      reloc.offset, false, *reloc.sym,
                                      reloc.addend, R_ABS});
              return true;
            });
        changed |= (it != part.relrAuthDyn->relocs.end());
        part.relrAuthDyn->relocs.erase(it, part.relrAuthDyn->relocs.end());
      }
      if (part.relaDyn)
        changed |= part.relaDyn->updateAllocSize(ctx);
      if (part.relrDyn)
        changed |= part.relrDyn->updateAllocSize(ctx);
      if (part.relrAuthDyn)
        changed |= part.relrAuthDyn->updateAllocSize(ctx);
      if (part.memtagGlobalDescriptors)
        changed |= part.memtagGlobalDescriptors->updateAllocSize(ctx);
    }

    std::pair<const OutputSection *, const Defined *> changes =
        ctx.script->assignAddresses();
    if (!changed) {
      // Some symbols may be dependent on section addresses. When we break the
      // loop, the symbol values are finalized because a previous
      // assignAddresses() finalized section addresses.
      if (!changes.first && !changes.second)
        break;
      if (++assignPasses == 5) {
        if (changes.first)
          Err(ctx) << "address (0x" << Twine::utohexstr(changes.first->addr)
                   << ") of section '" << changes.first->name
                   << "' does not converge";
        if (changes.second)
          Err(ctx) << "assignment to symbol " << changes.second
                   << " does not converge";
        break;
      }
    } else if (spilled) {
      // Spilling can change relative section order.
      finalizeOrderDependentContent();
    }
  }
  if (!ctx.arg.relocatable)
    ctx.target->finalizeRelax(pass);

  if (ctx.arg.relocatable)
    for (OutputSection *sec : ctx.outputSections)
      sec->addr = 0;

  uint64_t imageBase = ctx.script->hasSectionsCommand || ctx.arg.relocatable
                           ? 0
                           : ctx.target->getImageBase();
  for (SectionCommand *cmd : ctx.script->sectionCommands) {
    auto *osd = dyn_cast<OutputDesc>(cmd);
    if (!osd)
      continue;
    OutputSection *osec = &osd->osec;
    // Error if the address is below the image base when SECTIONS is absent
    // (e.g. when -Ttext is specified and smaller than the default target image
    // base for no-pie).
    if (osec->addr < imageBase && (osec->flags & SHF_ALLOC)) {
      Err(ctx) << "section '" << osec->name << "' address (0x"
               << Twine::utohexstr(osec->addr)
               << ") is smaller than image base (0x"
               << Twine::utohexstr(imageBase) << "); specify --image-base";
    }

    // If addrExpr is set, the address may not be a multiple of the alignment.
    // Warn because this is error-prone.
    if (osec->addr % osec->addralign != 0)
      Warn(ctx) << "address (0x" << Twine::utohexstr(osec->addr)
                << ") of section " << osec->name
                << " is not a multiple of alignment (" << osec->addralign
                << ")";
  }

  // Sizes are no longer allowed to grow, so all allowable spills have been
  // taken. Remove any leftover potential spills.
  ctx.script->erasePotentialSpillSections();
}

// If Input Sections have been shrunk (basic block sections) then
// update symbol values and sizes associated with these sections.  With basic
// block sections, input sections can shrink when the jump instructions at
// the end of the section are relaxed.
static void fixSymbolsAfterShrinking(Ctx &ctx) {
  for (InputFile *File : ctx.objectFiles) {
    parallelForEach(File->getSymbols(), [&](Symbol *Sym) {
      auto *def = dyn_cast<Defined>(Sym);
      if (!def)
        return;

      const SectionBase *sec = def->section;
      if (!sec)
        return;

      const InputSectionBase *inputSec = dyn_cast<InputSectionBase>(sec);
      if (!inputSec || !inputSec->bytesDropped)
        return;

      const size_t OldSize = inputSec->content().size();
      const size_t NewSize = OldSize - inputSec->bytesDropped;

      if (def->value > NewSize && def->value <= OldSize) {
        LLVM_DEBUG(llvm::dbgs()
                   << "Moving symbol " << Sym->getName() << " from "
                   << def->value << " to "
                   << def->value - inputSec->bytesDropped << " bytes\n");
        def->value -= inputSec->bytesDropped;
        return;
      }

      if (def->value + def->size > NewSize && def->value <= OldSize &&
          def->value + def->size <= OldSize) {
        LLVM_DEBUG(llvm::dbgs()
                   << "Shrinking symbol " << Sym->getName() << " from "
                   << def->size << " to " << def->size - inputSec->bytesDropped
                   << " bytes\n");
        def->size -= inputSec->bytesDropped;
      }
    });
  }
}

// If basic block sections exist, there are opportunities to delete fall thru
// jumps and shrink jump instructions after basic block reordering.  This
// relaxation pass does that.  It is only enabled when --optimize-bb-jumps
// option is used.
template <class ELFT> void Writer<ELFT>::optimizeBasicBlockJumps() {
  assert(ctx.arg.optimizeBBJumps);
  SmallVector<InputSection *, 0> storage;

  ctx.script->assignAddresses();
  // For every output section that has executable input sections, this
  // does the following:
  //   1. Deletes all direct jump instructions in input sections that
  //      jump to the following section as it is not required.
  //   2. If there are two consecutive jump instructions, it checks
  //      if they can be flipped and one can be deleted.
  for (OutputSection *osec : ctx.outputSections) {
    if (!(osec->flags & SHF_EXECINSTR))
      continue;
    ArrayRef<InputSection *> sections = getInputSections(*osec, storage);
    size_t numDeleted = 0;
    // Delete all fall through jump instructions.  Also, check if two
    // consecutive jump instructions can be flipped so that a fall
    // through jmp instruction can be deleted.
    for (size_t i = 0, e = sections.size(); i != e; ++i) {
      InputSection *next = i + 1 < sections.size() ? sections[i + 1] : nullptr;
      InputSection &sec = *sections[i];
      numDeleted += ctx.target->deleteFallThruJmpInsn(sec, sec.file, next);
    }
    if (numDeleted > 0) {
      ctx.script->assignAddresses();
      LLVM_DEBUG(llvm::dbgs()
                 << "Removing " << numDeleted << " fall through jumps\n");
    }
  }

  fixSymbolsAfterShrinking(ctx);

  for (OutputSection *osec : ctx.outputSections)
    for (InputSection *is : getInputSections(*osec, storage))
      is->trim();
}

// In order to allow users to manipulate linker-synthesized sections,
// we had to add synthetic sections to the input section list early,
// even before we make decisions whether they are needed. This allows
// users to write scripts like this: ".mygot : { .got }".
//
// Doing it has an unintended side effects. If it turns out that we
// don't need a .got (for example) at all because there's no
// relocation that needs a .got, we don't want to emit .got.
//
// To deal with the above problem, this function is called after
// scanRelocations is called to remove synthetic sections that turn
// out to be empty.
static void removeUnusedSyntheticSections(Ctx &ctx) {
  // All input synthetic sections that can be empty are placed after
  // all regular ones. Reverse iterate to find the first synthetic section
  // after a non-synthetic one which will be our starting point.
  auto start =
      llvm::find_if(llvm::reverse(ctx.inputSections), [](InputSectionBase *s) {
        return !isa<SyntheticSection>(s);
      }).base();

  // Remove unused synthetic sections from ctx.inputSections;
  DenseSet<InputSectionBase *> unused;
  auto end =
      std::remove_if(start, ctx.inputSections.end(), [&](InputSectionBase *s) {
        auto *sec = cast<SyntheticSection>(s);
        if (sec->getParent() && sec->isNeeded())
          return false;
        // .relr.auth.dyn relocations may be moved to .rela.dyn in
        // finalizeAddressDependentContent, making .rela.dyn no longer empty.
        // Conservatively keep .rela.dyn. .relr.auth.dyn can be made empty, but
        // we would fail to remove it here.
        if (ctx.arg.emachine == EM_AARCH64 && ctx.arg.relrPackDynRelocs &&
            sec == ctx.mainPart->relaDyn.get())
          return false;
        unused.insert(sec);
        return true;
      });
  ctx.inputSections.erase(end, ctx.inputSections.end());

  // Remove unused synthetic sections from the corresponding input section
  // description and orphanSections.
  for (auto *sec : unused)
    if (OutputSection *osec = cast<SyntheticSection>(sec)->getParent())
      for (SectionCommand *cmd : osec->commands)
        if (auto *isd = dyn_cast<InputSectionDescription>(cmd))
          llvm::erase_if(isd->sections, [&](InputSection *isec) {
            return unused.count(isec);
          });
  llvm::erase_if(ctx.script->orphanSections, [&](const InputSectionBase *sec) {
    return unused.count(sec);
  });
}

// Create output section objects and add them to OutputSections.
template <class ELFT> void Writer<ELFT>::finalizeSections() {
  if (!ctx.arg.relocatable) {
    ctx.out.preinitArray = findSection(ctx, ".preinit_array");
    ctx.out.initArray = findSection(ctx, ".init_array");
    ctx.out.finiArray = findSection(ctx, ".fini_array");

    // The linker needs to define SECNAME_start, SECNAME_end and SECNAME_stop
    // symbols for sections, so that the runtime can get the start and end
    // addresses of each section by section name. Add such symbols.
    addStartEndSymbols();
    for (SectionCommand *cmd : ctx.script->sectionCommands)
      if (auto *osd = dyn_cast<OutputDesc>(cmd))
        addStartStopSymbols(osd->osec);

    // Add _DYNAMIC symbol. Unlike GNU gold, our _DYNAMIC symbol has no type.
    // It should be okay as no one seems to care about the type.
    // Even the author of gold doesn't remember why gold behaves that way.
    // https://sourceware.org/ml/binutils/2002-03/msg00360.html
    if (ctx.mainPart->dynamic->parent) {
      Symbol *s = ctx.symtab->addSymbol(Defined{
          ctx, ctx.internalFile, "_DYNAMIC", STB_WEAK, STV_HIDDEN, STT_NOTYPE,
          /*value=*/0, /*size=*/0, ctx.mainPart->dynamic.get()});
      s->isUsedInRegularObj = true;
    }

    // Define __rel[a]_iplt_{start,end} symbols if needed.
    addRelIpltSymbols();

    // RISC-V's gp can address +/- 2 KiB, set it to .sdata + 0x800. This symbol
    // should only be defined in an executable. If .sdata does not exist, its
    // value/section does not matter but it has to be relative, so set its
    // st_shndx arbitrarily to 1 (ctx.out.elfHeader).
    if (ctx.arg.emachine == EM_RISCV) {
      if (!ctx.arg.shared) {
        OutputSection *sec = findSection(ctx, ".sdata");
        addOptionalRegular(ctx, "__global_pointer$",
                           sec ? sec : ctx.out.elfHeader.get(), 0x800,
                           STV_DEFAULT);
        // Set riscvGlobalPointer to be used by the optional global pointer
        // relaxation.
        if (ctx.arg.relaxGP) {
          Symbol *s = ctx.symtab->find("__global_pointer$");
          if (s && s->isDefined())
            ctx.sym.riscvGlobalPointer = cast<Defined>(s);
        }
      }
    }

    if (ctx.arg.emachine == EM_386 || ctx.arg.emachine == EM_X86_64) {
      // On targets that support TLSDESC, _TLS_MODULE_BASE_ is defined in such a
      // way that:
      //
      // 1) Without relaxation: it produces a dynamic TLSDESC relocation that
      // computes 0.
      // 2) With LD->LE relaxation: _TLS_MODULE_BASE_@tpoff = 0 (lowest address
      // in the TLS block).
      //
      // 2) is special cased in @tpoff computation. To satisfy 1), we define it
      // as an absolute symbol of zero. This is different from GNU linkers which
      // define _TLS_MODULE_BASE_ relative to the first TLS section.
      Symbol *s = ctx.symtab->find("_TLS_MODULE_BASE_");
      if (s && s->isUndefined()) {
        s->resolve(ctx, Defined{ctx, ctx.internalFile, StringRef(), STB_GLOBAL,
                                STV_HIDDEN, STT_TLS, /*value=*/0, 0,
                                /*section=*/nullptr});
        ctx.sym.tlsModuleBase = cast<Defined>(s);
      }
    }

    // This responsible for splitting up .eh_frame section into
    // pieces. The relocation scan uses those pieces, so this has to be
    // earlier.
    {
      llvm::TimeTraceScope timeScope("Finalize .eh_frame");
      for (Partition &part : ctx.partitions)
        finalizeSynthetic(ctx, part.ehFrame.get());
    }
  }

  // If the previous code block defines any non-hidden symbols (e.g.
  // __global_pointer$), they may be exported.
  if (ctx.arg.exportDynamic)
    for (Symbol *sym : ctx.synthesizedSymbols)
      if (sym->computeBinding(ctx) != STB_LOCAL)
        sym->isExported = true;

  demoteSymbolsAndComputeIsPreemptible(ctx);

  if (ctx.arg.copyRelocs && ctx.arg.discard != DiscardPolicy::None)
    markUsedLocalSymbols<ELFT>(ctx);
  demoteAndCopyLocalSymbols(ctx);

  if (ctx.arg.copyRelocs)
    addSectionSymbols();

  // Change values of linker-script-defined symbols from placeholders (assigned
  // by declareSymbols) to actual definitions.
  ctx.script->processSymbolAssignments();

  if (!ctx.arg.relocatable) {
    llvm::TimeTraceScope timeScope("Scan relocations");
    // Scan relocations. This must be done after every symbol is declared so
    // that we can correctly decide if a dynamic relocation is needed. This is
    // called after processSymbolAssignments() because it needs to know whether
    // a linker-script-defined symbol is absolute.
    scanRelocations<ELFT>(ctx);
    reportUndefinedSymbols(ctx);
    postScanRelocations(ctx);

    if (ctx.in.plt && ctx.in.plt->isNeeded())
      ctx.in.plt->addSymbols();
    if (ctx.in.iplt && ctx.in.iplt->isNeeded())
      ctx.in.iplt->addSymbols();

    if (ctx.arg.unresolvedSymbolsInShlib != UnresolvedPolicy::Ignore) {
      auto diag =
          ctx.arg.unresolvedSymbolsInShlib == UnresolvedPolicy::ReportError &&
                  !ctx.arg.noinhibitExec
              ? DiagLevel::Err
              : DiagLevel::Warn;
      // Error on undefined symbols in a shared object, if all of its DT_NEEDED
      // entries are seen. These cases would otherwise lead to runtime errors
      // reported by the dynamic linker.
      //
      // ld.bfd traces all DT_NEEDED to emulate the logic of the dynamic linker
      // to catch more cases. That is too much for us. Our approach resembles
      // the one used in ld.gold, achieves a good balance to be useful but not
      // too smart.
      //
      // If a DSO reference is resolved by a SharedSymbol, but the SharedSymbol
      // is overridden by a hidden visibility Defined (which is later discarded
      // due to GC), don't report the diagnostic. However, this may indicate an
      // unintended SharedSymbol.
      for (SharedFile *file : ctx.sharedFiles) {
        bool allNeededIsKnown =
            llvm::all_of(file->dtNeeded, [&](StringRef needed) {
              return ctx.symtab->soNames.count(CachedHashStringRef(needed));
            });
        if (!allNeededIsKnown)
          continue;
        for (Symbol *sym : file->requiredSymbols) {
          if (sym->dsoDefined)
            continue;
          if (sym->isUndefined() && !sym->isWeak()) {
            ELFSyncStream(ctx, diag)
                << "undefined reference: " << sym << "\n>>> referenced by "
                << file << " (disallowed by --no-allow-shlib-undefined)";
          } else if (sym->isDefined() &&
                     sym->computeBinding(ctx) == STB_LOCAL) {
            ELFSyncStream(ctx, diag)
                << "non-exported symbol '" << sym << "' in '" << sym->file
                << "' is referenced by DSO '" << file << "'";
          }
        }
      }
    }
  }

  {
    llvm::TimeTraceScope timeScope("Add symbols to symtabs");
    // Now that we have defined all possible global symbols including linker-
    // synthesized ones. Visit all symbols to give the finishing touches.
    for (Symbol *sym : ctx.symtab->getSymbols()) {
      if (!sym->isUsedInRegularObj || !includeInSymtab(ctx, *sym))
        continue;
      if (!ctx.arg.relocatable)
        sym->binding = sym->computeBinding(ctx);
      if (ctx.in.symTab)
        ctx.in.symTab->addSymbol(sym);

      // computeBinding might localize a symbol that was considered exported
      // but then synthesized as hidden (e.g. _DYNAMIC).
      if ((sym->isExported || sym->isPreemptible) && !sym->isLocal()) {
        ctx.partitions[sym->partition - 1].dynSymTab->addSymbol(sym);
        if (auto *file = dyn_cast<SharedFile>(sym->file))
          if (file->isNeeded && !sym->isUndefined())
            addVerneed(ctx, *sym);
      }
    }

    // We also need to scan the dynamic relocation tables of the other
    // partitions and add any referenced symbols to the partition's dynsym.
    for (Partition &part :
         MutableArrayRef<Partition>(ctx.partitions).slice(1)) {
      DenseSet<Symbol *> syms;
      for (const SymbolTableEntry &e : part.dynSymTab->getSymbols())
        syms.insert(e.sym);
      for (DynamicReloc &reloc : part.relaDyn->relocs)
        if (reloc.sym && reloc.needsDynSymIndex() &&
            syms.insert(reloc.sym).second)
          part.dynSymTab->addSymbol(reloc.sym);
    }
  }

  if (ctx.in.mipsGot)
    ctx.in.mipsGot->build();

  removeUnusedSyntheticSections(ctx);
  ctx.script->diagnoseOrphanHandling();
  ctx.script->diagnoseMissingSGSectionAddress();

  sortSections();

  // Create a list of OutputSections, assign sectionIndex, and populate
  // ctx.in.shStrTab. If -z nosectionheader is specified, drop non-ALLOC
  // sections.
  for (SectionCommand *cmd : ctx.script->sectionCommands)
    if (auto *osd = dyn_cast<OutputDesc>(cmd)) {
      OutputSection *osec = &osd->osec;
      if (!ctx.in.shStrTab && !(osec->flags & SHF_ALLOC))
        continue;
      ctx.outputSections.push_back(osec);
      osec->sectionIndex = ctx.outputSections.size();
      if (ctx.in.shStrTab)
        osec->shName = ctx.in.shStrTab->addString(osec->name);
    }

  // Prefer command line supplied address over other constraints.
  for (OutputSection *sec : ctx.outputSections) {
    auto i = ctx.arg.sectionStartMap.find(sec->name);
    if (i != ctx.arg.sectionStartMap.end())
      sec->addrExpr = [=] { return i->second; };
  }

  // With the ctx.outputSections available check for GDPLT relocations
  // and add __tls_get_addr symbol if needed.
  if (ctx.arg.emachine == EM_HEXAGON &&
      hexagonNeedsTLSSymbol(ctx.outputSections)) {
    Symbol *sym =
        ctx.symtab->addSymbol(Undefined{ctx.internalFile, "__tls_get_addr",
                                        STB_GLOBAL, STV_DEFAULT, STT_NOTYPE});
    sym->isPreemptible = true;
    ctx.partitions[0].dynSymTab->addSymbol(sym);
  }

  // This is a bit of a hack. A value of 0 means undef, so we set it
  // to 1 to make __ehdr_start defined. The section number is not
  // particularly relevant.
  ctx.out.elfHeader->sectionIndex = 1;
  ctx.out.elfHeader->size = sizeof(typename ELFT::Ehdr);

  // Binary and relocatable output does not have PHDRS.
  // The headers have to be created before finalize as that can influence the
  // image base and the dynamic section on mips includes the image base.
  if (!ctx.arg.relocatable && !ctx.arg.oFormatBinary) {
    for (Partition &part : ctx.partitions) {
      part.phdrs = ctx.script->hasPhdrsCommands() ? ctx.script->createPhdrs()
                                                  : createPhdrs(part);
      if (ctx.arg.emachine == EM_ARM) {
        // PT_ARM_EXIDX is the ARM EHABI equivalent of PT_GNU_EH_FRAME
        addPhdrForSection(part, SHT_ARM_EXIDX, PT_ARM_EXIDX, PF_R);
      }
      if (ctx.arg.emachine == EM_MIPS) {
        // Add separate segments for MIPS-specific sections.
        addPhdrForSection(part, SHT_MIPS_REGINFO, PT_MIPS_REGINFO, PF_R);
        addPhdrForSection(part, SHT_MIPS_OPTIONS, PT_MIPS_OPTIONS, PF_R);
        addPhdrForSection(part, SHT_MIPS_ABIFLAGS, PT_MIPS_ABIFLAGS, PF_R);
      }
      if (ctx.arg.emachine == EM_RISCV)
        addPhdrForSection(part, SHT_RISCV_ATTRIBUTES, PT_RISCV_ATTRIBUTES,
                          PF_R);
    }
    ctx.out.programHeaders->size =
        sizeof(Elf_Phdr) * ctx.mainPart->phdrs.size();

    // Find the TLS segment. This happens before the section layout loop so that
    // Android relocation packing can look up TLS symbol addresses. We only need
    // to care about the main partition here because all TLS symbols were moved
    // to the main partition (see MarkLive.cpp).
    for (auto &p : ctx.mainPart->phdrs)
      if (p->p_type == PT_TLS)
        ctx.tlsPhdr = p.get();
  }

  // Some symbols are defined in term of program headers. Now that we
  // have the headers, we can find out which sections they point to.
  setReservedSymbolSections();

  if (ctx.script->noCrossRefs.size()) {
    llvm::TimeTraceScope timeScope("Check NOCROSSREFS");
    checkNoCrossRefs<ELFT>(ctx);
  }

  {
    llvm::TimeTraceScope timeScope("Finalize synthetic sections");

    finalizeSynthetic(ctx, ctx.in.bss.get());
    finalizeSynthetic(ctx, ctx.in.bssRelRo.get());
    finalizeSynthetic(ctx, ctx.in.symTabShndx.get());
    finalizeSynthetic(ctx, ctx.in.shStrTab.get());
    finalizeSynthetic(ctx, ctx.in.strTab.get());
    finalizeSynthetic(ctx, ctx.in.got.get());
    finalizeSynthetic(ctx, ctx.in.mipsGot.get());
    finalizeSynthetic(ctx, ctx.in.igotPlt.get());
    finalizeSynthetic(ctx, ctx.in.gotPlt.get());
    finalizeSynthetic(ctx, ctx.in.relaPlt.get());
    finalizeSynthetic(ctx, ctx.in.plt.get());
    finalizeSynthetic(ctx, ctx.in.iplt.get());
    finalizeSynthetic(ctx, ctx.in.ppc32Got2.get());
    finalizeSynthetic(ctx, ctx.in.partIndex.get());

    // Dynamic section must be the last one in this list and dynamic
    // symbol table section (dynSymTab) must be the first one.
    for (Partition &part : ctx.partitions) {
      if (part.relaDyn) {
        part.relaDyn->mergeRels();
        // Compute DT_RELACOUNT to be used by part.dynamic.
        part.relaDyn->partitionRels();
        finalizeSynthetic(ctx, part.relaDyn.get());
      }
      if (part.relrDyn) {
        part.relrDyn->mergeRels();
        finalizeSynthetic(ctx, part.relrDyn.get());
      }
      if (part.relrAuthDyn) {
        part.relrAuthDyn->mergeRels();
        finalizeSynthetic(ctx, part.relrAuthDyn.get());
      }

      finalizeSynthetic(ctx, part.dynSymTab.get());
      finalizeSynthetic(ctx, part.gnuHashTab.get());
      finalizeSynthetic(ctx, part.hashTab.get());
      finalizeSynthetic(ctx, part.verDef.get());
      finalizeSynthetic(ctx, part.ehFrameHdr.get());
      finalizeSynthetic(ctx, part.verSym.get());
      finalizeSynthetic(ctx, part.verNeed.get());
      finalizeSynthetic(ctx, part.dynamic.get());
    }
  }

  if (!ctx.script->hasSectionsCommand && !ctx.arg.relocatable)
    fixSectionAlignments();

  // This is used to:
  // 1) Create "thunks":
  //    Jump instructions in many ISAs have small displacements, and therefore
  //    they cannot jump to arbitrary addresses in memory. For example, RISC-V
  //    JAL instruction can target only +-1 MiB from PC. It is a linker's
  //    responsibility to create and insert small pieces of code between
  //    sections to extend the ranges if jump targets are out of range. Such
  //    code pieces are called "thunks".
  //
  //    We add thunks at this stage. We couldn't do this before this point
  //    because this is the earliest point where we know sizes of sections and
  //    their layouts (that are needed to determine if jump targets are in
  //    range).
  //
  // 2) Update the sections. We need to generate content that depends on the
  //    address of InputSections. For example, MIPS GOT section content or
  //    android packed relocations sections content.
  //
  // 3) Assign the final values for the linker script symbols. Linker scripts
  //    sometimes using forward symbol declarations. We want to set the correct
  //    values. They also might change after adding the thunks.
  finalizeAddressDependentContent();

  // All information needed for OutputSection part of Map file is available.
  if (errCount(ctx))
    return;

  {
    llvm::TimeTraceScope timeScope("Finalize synthetic sections");
    // finalizeAddressDependentContent may have added local symbols to the
    // static symbol table.
    finalizeSynthetic(ctx, ctx.in.symTab.get());
    finalizeSynthetic(ctx, ctx.in.debugNames.get());
    finalizeSynthetic(ctx, ctx.in.ppc64LongBranchTarget.get());
    finalizeSynthetic(ctx, ctx.in.armCmseSGSection.get());
  }

  // Relaxation to delete inter-basic block jumps created by basic block
  // sections. Run after ctx.in.symTab is finalized as optimizeBasicBlockJumps
  // can relax jump instructions based on symbol offset.
  if (ctx.arg.optimizeBBJumps)
    optimizeBasicBlockJumps();

  // Fill other section headers. The dynamic table is finalized
  // at the end because some tags like RELSZ depend on result
  // of finalizing other sections.
  for (OutputSection *sec : ctx.outputSections)
    sec->finalize(ctx);

  ctx.script->checkFinalScriptConditions();

  if (ctx.arg.emachine == EM_ARM && !ctx.arg.isLE && ctx.arg.armBe8) {
    addArmInputSectionMappingSymbols(ctx);
    sortArmMappingSymbols(ctx);
  }
}

// Ensure data sections are not mixed with executable sections when
// --execute-only is used. --execute-only make pages executable but not
// readable.
template <class ELFT> void Writer<ELFT>::checkExecuteOnly() {
  if (!ctx.arg.executeOnly)
    return;

  SmallVector<InputSection *, 0> storage;
  for (OutputSection *osec : ctx.outputSections)
    if (osec->flags & SHF_EXECINSTR)
      for (InputSection *isec : getInputSections(*osec, storage))
        if (!(isec->flags & SHF_EXECINSTR))
          ErrAlways(ctx) << "cannot place " << isec << " into " << osec->name
                         << ": --execute-only does not support intermingling "
                            "data and code";
}

// Check which input sections of RX output sections don't have the
// SHF_AARCH64_PURECODE or SHF_ARM_PURECODE flag set.
template <class ELFT> void Writer<ELFT>::checkExecuteOnlyReport() {
  if (ctx.arg.zExecuteOnlyReport == ReportPolicy::None)
    return;

  auto reportUnless = [&](bool cond) -> ELFSyncStream {
    if (cond)
      return {ctx, DiagLevel::None};
    return {ctx, toDiagLevel(ctx.arg.zExecuteOnlyReport)};
  };

  uint64_t purecodeFlag =
      ctx.arg.emachine == EM_AARCH64 ? SHF_AARCH64_PURECODE : SHF_ARM_PURECODE;
  StringRef purecodeFlagName = ctx.arg.emachine == EM_AARCH64
                                   ? "SHF_AARCH64_PURECODE"
                                   : "SHF_ARM_PURECODE";
  SmallVector<InputSection *, 0> storage;
  for (OutputSection *osec : ctx.outputSections) {
    if (osec->getPhdrFlags() != (PF_R | PF_X))
      continue;
    for (InputSection *sec : getInputSections(*osec, storage)) {
      if (isa<SyntheticSection>(sec))
        continue;
      reportUnless(sec->flags & purecodeFlag)
          << "-z execute-only-report: " << sec << " does not have "
          << purecodeFlagName << " flag set";
    }
  }
}

// The linker is expected to define SECNAME_start and SECNAME_end
// symbols for a few sections. This function defines them.
template <class ELFT> void Writer<ELFT>::addStartEndSymbols() {
  // If the associated output section does not exist, there is ambiguity as to
  // how we define _start and _end symbols for an init/fini section. Users
  // expect no "undefined symbol" linker errors and loaders expect equal
  // st_value but do not particularly care whether the symbols are defined or
  // not. We retain the output section so that the section indexes will be
  // correct.
  auto define = [=](StringRef start, StringRef end, OutputSection *os) {
    if (os) {
      Defined *startSym = addOptionalRegular(ctx, start, os, 0);
      Defined *stopSym = addOptionalRegular(ctx, end, os, -1);
      if (startSym || stopSym)
        os->usedInExpression = true;
    } else {
      addOptionalRegular(ctx, start, ctx.out.elfHeader.get(), 0);
      addOptionalRegular(ctx, end, ctx.out.elfHeader.get(), 0);
    }
  };

  define("__preinit_array_start", "__preinit_array_end", ctx.out.preinitArray);
  define("__init_array_start", "__init_array_end", ctx.out.initArray);
  define("__fini_array_start", "__fini_array_end", ctx.out.finiArray);

  // As a special case, don't unnecessarily retain .ARM.exidx, which would
  // create an empty PT_ARM_EXIDX.
  if (OutputSection *sec = findSection(ctx, ".ARM.exidx"))
    define("__exidx_start", "__exidx_end", sec);
}

// If a section name is valid as a C identifier (which is rare because of
// the leading '.'), linkers are expected to define __start_<secname> and
// __stop_<secname> symbols. They are at beginning and end of the section,
// respectively. This is not requested by the ELF standard, but GNU ld and
// gold provide the feature, and used by many programs.
template <class ELFT>
void Writer<ELFT>::addStartStopSymbols(OutputSection &osec) {
  StringRef s = osec.name;
  if (!isValidCIdentifier(s))
    return;
  StringSaver &ss = ctx.saver;
  Defined *startSym = addOptionalRegular(ctx, ss.save("__start_" + s), &osec, 0,
                                         ctx.arg.zStartStopVisibility);
  Defined *stopSym = addOptionalRegular(ctx, ss.save("__stop_" + s), &osec, -1,
                                        ctx.arg.zStartStopVisibility);
  if (startSym || stopSym)
    osec.usedInExpression = true;
}

static bool needsPtLoad(OutputSection *sec) {
  if (!(sec->flags & SHF_ALLOC))
    return false;

  // Don't allocate VA space for TLS NOBITS sections. The PT_TLS PHDR is
  // responsible for allocating space for them, not the PT_LOAD that
  // contains the TLS initialization image.
  if ((sec->flags & SHF_TLS) && sec->type == SHT_NOBITS)
    return false;
  return true;
}

// Adjust phdr flags according to certain options.
static uint64_t computeFlags(Ctx &ctx, uint64_t flags) {
  if (ctx.arg.omagic)
    return PF_R | PF_W | PF_X;
  if (ctx.arg.executeOnly && (flags & PF_X))
    return flags & ~PF_R;
  return flags;
}

// Decide which program headers to create and which sections to include in each
// one.
template <class ELFT>
SmallVector<std::unique_ptr<PhdrEntry>, 0>
Writer<ELFT>::createPhdrs(Partition &part) {
  SmallVector<std::unique_ptr<PhdrEntry>, 0> ret;
  auto addHdr = [&, &ctx = ctx](unsigned type, unsigned flags) -> PhdrEntry * {
    ret.push_back(std::make_unique<PhdrEntry>(ctx, type, flags));
    return ret.back().get();
  };

  unsigned partNo = part.getNumber(ctx);
  bool isMain = partNo == 1;

  // Add the first PT_LOAD segment for regular output sections.
  uint64_t flags = computeFlags(ctx, PF_R);
  PhdrEntry *load = nullptr;

  // nmagic or omagic output does not have PT_PHDR, PT_INTERP, or the readonly
  // PT_LOAD.
  if (!ctx.arg.nmagic && !ctx.arg.omagic) {
    // The first phdr entry is PT_PHDR which describes the program header
    // itself.
    if (isMain)
      addHdr(PT_PHDR, PF_R)->add(ctx.out.programHeaders.get());
    else
      addHdr(PT_PHDR, PF_R)->add(part.programHeaders->getParent());

    // PT_INTERP must be the second entry if exists.
    if (OutputSection *cmd = findSection(ctx, ".interp", partNo))
      addHdr(PT_INTERP, cmd->getPhdrFlags())->add(cmd);

    // Add the headers. We will remove them if they don't fit.
    // In the other partitions the headers are ordinary sections, so they don't
    // need to be added here.
    if (isMain) {
      load = addHdr(PT_LOAD, flags);
      load->add(ctx.out.elfHeader.get());
      load->add(ctx.out.programHeaders.get());
    }
  }

  // PT_GNU_RELRO includes all sections that should be marked as
  // read-only by dynamic linker after processing relocations.
  // Current dynamic loaders only support one PT_GNU_RELRO PHDR, give
  // an error message if more than one PT_GNU_RELRO PHDR is required.
  auto relRo = std::make_unique<PhdrEntry>(ctx, PT_GNU_RELRO, PF_R);
  bool inRelroPhdr = false;
  OutputSection *relroEnd = nullptr;
  for (OutputSection *sec : ctx.outputSections) {
    if (sec->partition != partNo || !needsPtLoad(sec))
      continue;
    if (isRelroSection(ctx, sec)) {
      inRelroPhdr = true;
      if (!relroEnd)
        relRo->add(sec);
      else
        ErrAlways(ctx) << "section: " << sec->name
                       << " is not contiguous with other relro" << " sections";
    } else if (inRelroPhdr) {
      inRelroPhdr = false;
      relroEnd = sec;
    }
  }
  relRo->p_align = 1;

  for (OutputSection *sec : ctx.outputSections) {
    if (!needsPtLoad(sec))
      continue;

    // Normally, sections in partitions other than the current partition are
    // ignored. But partition number 255 is a special case: it contains the
    // partition end marker (.part.end). It needs to be added to the main
    // partition so that a segment is created for it in the main partition,
    // which will cause the dynamic loader to reserve space for the other
    // partitions.
    if (sec->partition != partNo) {
      if (isMain && sec->partition == 255)
        addHdr(PT_LOAD, computeFlags(ctx, sec->getPhdrFlags()))->add(sec);
      continue;
    }

    // Segments are contiguous memory regions that has the same attributes
    // (e.g. executable or writable). There is one phdr for each segment.
    // Therefore, we need to create a new phdr when the next section has
    // incompatible flags or is loaded at a discontiguous address or memory
    // region using AT or AT> linker script command, respectively.
    //
    // As an exception, we don't create a separate load segment for the ELF
    // headers, even if the first "real" output has an AT or AT> attribute.
    //
    // In addition, NOBITS sections should only be placed at the end of a LOAD
    // segment (since it's represented as p_filesz < p_memsz). If we have a
    // not-NOBITS section after a NOBITS, we create a new LOAD for the latter
    // even if flags match, so as not to require actually writing the
    // supposed-to-be-NOBITS section to the output file. (However, we cannot do
    // so when hasSectionsCommand, since we cannot introduce the extra alignment
    // needed to create a new LOAD)
    uint64_t newFlags = computeFlags(ctx, sec->getPhdrFlags());
    uint64_t incompatible = flags ^ newFlags;
    if (!(newFlags & PF_W)) {
      // When --no-rosegment is specified, RO and RX sections are compatible.
      if (ctx.arg.singleRoRx)
        incompatible &= ~PF_X;
      // When --no-xosegment is specified (the default), XO and RX sections are
      // compatible.
      if (ctx.arg.singleXoRx)
        incompatible &= ~PF_R;
    }
    if (incompatible)
      load = nullptr;

    bool sameLMARegion =
        load && !sec->lmaExpr && sec->lmaRegion == load->firstSec->lmaRegion;
    if (load && sec != relroEnd &&
        sec->memRegion == load->firstSec->memRegion &&
        (sameLMARegion || load->lastSec == ctx.out.programHeaders.get()) &&
        (ctx.script->hasSectionsCommand || sec->type == SHT_NOBITS ||
         load->lastSec->type != SHT_NOBITS)) {
      load->p_flags |= newFlags;
    } else {
      load = addHdr(PT_LOAD, newFlags);
      flags = newFlags;
    }

    load->add(sec);
  }

  // Add a TLS segment if any.
  auto tlsHdr = std::make_unique<PhdrEntry>(ctx, PT_TLS, PF_R);
  for (OutputSection *sec : ctx.outputSections)
    if (sec->partition == partNo && sec->flags & SHF_TLS)
      tlsHdr->add(sec);
  if (tlsHdr->firstSec)
    ret.push_back(std::move(tlsHdr));

  // Add an entry for .dynamic.
  if (OutputSection *sec = part.dynamic->getParent())
    addHdr(PT_DYNAMIC, sec->getPhdrFlags())->add(sec);

  if (relRo->firstSec)
    ret.push_back(std::move(relRo));

  // PT_GNU_EH_FRAME is a special section pointing on .eh_frame_hdr.
  if (part.ehFrame->isNeeded() && part.ehFrameHdr &&
      part.ehFrame->getParent() && part.ehFrameHdr->getParent())
    addHdr(PT_GNU_EH_FRAME, part.ehFrameHdr->getParent()->getPhdrFlags())
        ->add(part.ehFrameHdr->getParent());

  if (ctx.arg.osabi == ELFOSABI_OPENBSD) {
    // PT_OPENBSD_MUTABLE makes the dynamic linker fill the segment with
    // zero data, like bss, but it can be treated differently.
    if (OutputSection *cmd = findSection(ctx, ".openbsd.mutable", partNo))
      addHdr(PT_OPENBSD_MUTABLE, cmd->getPhdrFlags())->add(cmd);

    // PT_OPENBSD_RANDOMIZE makes the dynamic linker fill the segment
    // with random data.
    if (OutputSection *cmd = findSection(ctx, ".openbsd.randomdata", partNo))
      addHdr(PT_OPENBSD_RANDOMIZE, cmd->getPhdrFlags())->add(cmd);

    // PT_OPENBSD_SYSCALLS makes the kernel and dynamic linker register
    // system call sites.
    if (OutputSection *cmd = findSection(ctx, ".openbsd.syscalls", partNo))
      addHdr(PT_OPENBSD_SYSCALLS, cmd->getPhdrFlags())->add(cmd);
  }

  if (ctx.arg.zGnustack != GnuStackKind::None) {
    // PT_GNU_STACK is a special section to tell the loader to make the
    // pages for the stack non-executable. If you really want an executable
    // stack, you can pass -z execstack, but that's not recommended for
    // security reasons.
    unsigned perm = PF_R | PF_W;
    if (ctx.arg.zGnustack == GnuStackKind::Exec)
      perm |= PF_X;
    addHdr(PT_GNU_STACK, perm)->p_memsz = ctx.arg.zStackSize;
  }

  // PT_OPENBSD_NOBTCFI is an OpenBSD-specific header to mark that the
  // executable is expected to violate branch-target CFI checks.
  if (ctx.arg.zNoBtCfi)
    addHdr(PT_OPENBSD_NOBTCFI, PF_X);

  // PT_OPENBSD_WXNEEDED is a OpenBSD-specific header to mark the executable
  // is expected to perform W^X violations, such as calling mprotect(2) or
  // mmap(2) with PROT_WRITE | PROT_EXEC, which is prohibited by default on
  // OpenBSD.
  if (ctx.arg.zWxneeded)
    addHdr(PT_OPENBSD_WXNEEDED, PF_X);

  if (OutputSection *cmd = findSection(ctx, ".note.gnu.property", partNo))
    addHdr(PT_GNU_PROPERTY, PF_R)->add(cmd);

  // Create one PT_NOTE per a group of contiguous SHT_NOTE sections with the
  // same alignment.
  PhdrEntry *note = nullptr;
  for (OutputSection *sec : ctx.outputSections) {
    if (sec->partition != partNo)
      continue;
    if (sec->type == SHT_NOTE && (sec->flags & SHF_ALLOC)) {
      if (!note || sec->lmaExpr || note->lastSec->addralign != sec->addralign)
        note = addHdr(PT_NOTE, PF_R);
      note->add(sec);
    } else {
      note = nullptr;
    }
  }
  return ret;
}

template <class ELFT>
void Writer<ELFT>::addPhdrForSection(Partition &part, unsigned shType,
                                     unsigned pType, unsigned pFlags) {
  unsigned partNo = part.getNumber(ctx);
  auto i = llvm::find_if(ctx.outputSections, [=](OutputSection *cmd) {
    return cmd->partition == partNo && cmd->type == shType;
  });
  if (i == ctx.outputSections.end())
    return;

  auto entry = std::make_unique<PhdrEntry>(ctx, pType, pFlags);
  entry->add(*i);
  part.phdrs.push_back(std::move(entry));
}

// Place the first section of each PT_LOAD to a different page (of maxPageSize).
// This is achieved by assigning an alignment expression to addrExpr of each
// such section.
template <class ELFT> void Writer<ELFT>::fixSectionAlignments() {
  const PhdrEntry *prev;
  auto pageAlign = [&, &ctx = this->ctx](const PhdrEntry *p) {
    OutputSection *cmd = p->firstSec;
    if (!cmd)
      return;
    cmd->alignExpr = [align = cmd->addralign]() { return align; };
    if (!cmd->addrExpr) {
      // Prefer advancing to align(dot, maxPageSize) + dot%maxPageSize to avoid
      // padding in the file contents.
      //
      // When -z separate-code is used we must not have any overlap in pages
      // between an executable segment and a non-executable segment. We align to
      // the next maximum page size boundary on transitions between executable
      // and non-executable segments.
      //
      // SHT_LLVM_PART_EHDR marks the start of a partition. The partition
      // sections will be extracted to a separate file. Align to the next
      // maximum page size boundary so that we can find the ELF header at the
      // start. We cannot benefit from overlapping p_offset ranges with the
      // previous segment anyway.
      if (ctx.arg.zSeparate == SeparateSegmentKind::Loadable ||
          (ctx.arg.zSeparate == SeparateSegmentKind::Code && prev &&
           (prev->p_flags & PF_X) != (p->p_flags & PF_X)) ||
          cmd->type == SHT_LLVM_PART_EHDR)
        cmd->addrExpr = [&ctx = this->ctx] {
          return alignToPowerOf2(ctx.script->getDot(), ctx.arg.maxPageSize);
        };
      // PT_TLS is at the start of the first RW PT_LOAD. If `p` includes PT_TLS,
      // it must be the RW. Align to p_align(PT_TLS) to make sure
      // p_vaddr(PT_LOAD)%p_align(PT_LOAD) = 0. Otherwise, if
      // sh_addralign(.tdata) < sh_addralign(.tbss), we will set p_align(PT_TLS)
      // to sh_addralign(.tbss), while p_vaddr(PT_TLS)=p_vaddr(PT_LOAD) may not
      // be congruent to 0 modulo p_align(PT_TLS).
      //
      // Technically this is not required, but as of 2019, some dynamic loaders
      // don't handle p_vaddr%p_align != 0 correctly, e.g. glibc (i386 and
      // x86-64) doesn't make runtime address congruent to p_vaddr modulo
      // p_align for dynamic TLS blocks (PR/24606), FreeBSD rtld has the same
      // bug, musl (TLS Variant 1 architectures) before 1.1.23 handled TLS
      // blocks correctly. We need to keep the workaround for a while.
      else if (ctx.tlsPhdr && ctx.tlsPhdr->firstSec == p->firstSec)
        cmd->addrExpr = [&ctx] {
          return alignToPowerOf2(ctx.script->getDot(), ctx.arg.maxPageSize) +
                 alignToPowerOf2(ctx.script->getDot() % ctx.arg.maxPageSize,
                                 ctx.tlsPhdr->p_align);
        };
      else
        cmd->addrExpr = [&ctx] {
          return alignToPowerOf2(ctx.script->getDot(), ctx.arg.maxPageSize) +
                 ctx.script->getDot() % ctx.arg.maxPageSize;
        };
    }
  };

  for (Partition &part : ctx.partitions) {
    prev = nullptr;
    for (auto &p : part.phdrs)
      if (p->p_type == PT_LOAD && p->firstSec) {
        pageAlign(p.get());
        prev = p.get();
      }
  }
}

// Compute an in-file position for a given section. The file offset must be the
// same with its virtual address modulo the page size, so that the loader can
// load executables without any address adjustment.
static uint64_t computeFileOffset(Ctx &ctx, OutputSection *os, uint64_t off) {
  // The first section in a PT_LOAD has to have congruent offset and address
  // modulo the maximum page size.
  if (os->ptLoad && os->ptLoad->firstSec == os)
    return alignTo(off, os->ptLoad->p_align, os->addr);

  // File offsets are not significant for .bss sections other than the first one
  // in a PT_LOAD/PT_TLS. By convention, we keep section offsets monotonically
  // increasing rather than setting to zero.
  if (os->type == SHT_NOBITS && (!ctx.tlsPhdr || ctx.tlsPhdr->firstSec != os))
    return off;

  // If the section is not in a PT_LOAD, we just have to align it.
  if (!os->ptLoad)
     return alignToPowerOf2(off, os->addralign);

  // If two sections share the same PT_LOAD the file offset is calculated
  // using this formula: Off2 = Off1 + (VA2 - VA1).
  OutputSection *first = os->ptLoad->firstSec;
  return first->offset + os->addr - first->addr;
}

template <class ELFT> void Writer<ELFT>::assignFileOffsetsBinary() {
  // Compute the minimum LMA of all non-empty non-NOBITS sections as minAddr.
  auto needsOffset = [](OutputSection &sec) {
    return sec.type != SHT_NOBITS && (sec.flags & SHF_ALLOC) && sec.size > 0;
  };
  uint64_t minAddr = UINT64_MAX;
  for (OutputSection *sec : ctx.outputSections)
    if (needsOffset(*sec)) {
      sec->offset = sec->getLMA();
      minAddr = std::min(minAddr, sec->offset);
    }

  // Sections are laid out at LMA minus minAddr.
  fileSize = 0;
  for (OutputSection *sec : ctx.outputSections)
    if (needsOffset(*sec)) {
      sec->offset -= minAddr;
      fileSize = std::max(fileSize, sec->offset + sec->size);
    }
}

static std::string rangeToString(uint64_t addr, uint64_t len) {
  return "[0x" + utohexstr(addr) + ", 0x" + utohexstr(addr + len - 1) + "]";
}

// Assign file offsets to output sections.
template <class ELFT> void Writer<ELFT>::assignFileOffsets() {
  ctx.out.programHeaders->offset = ctx.out.elfHeader->size;
  uint64_t off = ctx.out.elfHeader->size + ctx.out.programHeaders->size;

  PhdrEntry *lastRX = nullptr;
  for (Partition &part : ctx.partitions)
    for (auto &p : part.phdrs)
      if (p->p_type == PT_LOAD && (p->p_flags & PF_X))
        lastRX = p.get();

  // Layout SHF_ALLOC sections before non-SHF_ALLOC sections. A non-SHF_ALLOC
  // will not occupy file offsets contained by a PT_LOAD.
  for (OutputSection *sec : ctx.outputSections) {
    if (!(sec->flags & SHF_ALLOC))
      continue;
    off = computeFileOffset(ctx, sec, off);
    sec->offset = off;
    if (sec->type != SHT_NOBITS)
      off += sec->size;

    // If this is a last section of the last executable segment and that
    // segment is the last loadable segment, align the offset of the
    // following section to avoid loading non-segments parts of the file.
    if (ctx.arg.zSeparate != SeparateSegmentKind::None && lastRX &&
        lastRX->lastSec == sec)
      off = alignToPowerOf2(off, ctx.arg.maxPageSize);
  }
  for (OutputSection *osec : ctx.outputSections) {
    if (osec->flags & SHF_ALLOC)
      continue;
    osec->offset = alignToPowerOf2(off, osec->addralign);
    off = osec->offset + osec->size;
  }

  sectionHeaderOff = alignToPowerOf2(off, ctx.arg.wordsize);
  fileSize =
      sectionHeaderOff + (ctx.outputSections.size() + 1) * sizeof(Elf_Shdr);

  // Our logic assumes that sections have rising VA within the same segment.
  // With use of linker scripts it is possible to violate this rule and get file
  // offset overlaps or overflows. That should never happen with a valid script
  // which does not move the location counter backwards and usually scripts do
  // not do that. Unfortunately, there are apps in the wild, for example, Linux
  // kernel, which control segment distribution explicitly and move the counter
  // backwards, so we have to allow doing that to support linking them. We
  // perform non-critical checks for overlaps in checkSectionOverlap(), but here
  // we want to prevent file size overflows because it would crash the linker.
  for (OutputSection *sec : ctx.outputSections) {
    if (sec->type == SHT_NOBITS)
      continue;
    if ((sec->offset > fileSize) || (sec->offset + sec->size > fileSize))
      ErrAlways(ctx) << "unable to place section " << sec->name
                     << " at file offset "
                     << rangeToString(sec->offset, sec->size)
                     << "; check your linker script for overflows";
  }
}

// Finalize the program headers. We call this function after we assign
// file offsets and VAs to all sections.
template <class ELFT> void Writer<ELFT>::setPhdrs(Partition &part) {
  for (std::unique_ptr<PhdrEntry> &p : part.phdrs) {
    OutputSection *first = p->firstSec;
    OutputSection *last = p->lastSec;

    // .ARM.exidx sections may not be within a single .ARM.exidx
    // output section. We always want to describe just the
    // SyntheticSection.
    if (part.armExidx && p->p_type == PT_ARM_EXIDX) {
      p->p_filesz = part.armExidx->getSize();
      p->p_memsz = p->p_filesz;
      p->p_offset = first->offset + part.armExidx->outSecOff;
      p->p_vaddr = first->addr + part.armExidx->outSecOff;
      p->p_align = part.armExidx->addralign;
      if (part.elfHeader)
        p->p_offset -= part.elfHeader->getParent()->offset;

      if (!p->hasLMA)
        p->p_paddr = first->getLMA() + part.armExidx->outSecOff;
      return;
    }

    if (first) {
      p->p_filesz = last->offset - first->offset;
      if (last->type != SHT_NOBITS)
        p->p_filesz += last->size;

      p->p_memsz = last->addr + last->size - first->addr;
      p->p_offset = first->offset;
      p->p_vaddr = first->addr;

      // File offsets in partitions other than the main partition are relative
      // to the offset of the ELF headers. Perform that adjustment now.
      if (part.elfHeader)
        p->p_offset -= part.elfHeader->getParent()->offset;

      if (!p->hasLMA)
        p->p_paddr = first->getLMA();
    }
  }
}

// A helper struct for checkSectionOverlap.
namespace {
struct SectionOffset {
  OutputSection *sec;
  uint64_t offset;
};
} // namespace

// Check whether sections overlap for a specific address range (file offsets,
// load and virtual addresses).
static void checkOverlap(Ctx &ctx, StringRef name,
                         std::vector<SectionOffset> &sections,
                         bool isVirtualAddr) {
  llvm::sort(sections, [=](const SectionOffset &a, const SectionOffset &b) {
    return a.offset < b.offset;
  });

  // Finding overlap is easy given a vector is sorted by start position.
  // If an element starts before the end of the previous element, they overlap.
  for (size_t i = 1, end = sections.size(); i < end; ++i) {
    SectionOffset a = sections[i - 1];
    SectionOffset b = sections[i];
    if (b.offset >= a.offset + a.sec->size)
      continue;

    // If both sections are in OVERLAY we allow the overlapping of virtual
    // addresses, because it is what OVERLAY was designed for.
    if (isVirtualAddr && a.sec->inOverlay && b.sec->inOverlay)
      continue;

    Err(ctx) << "section " << a.sec->name << " " << name
             << " range overlaps with " << b.sec->name << "\n>>> "
             << a.sec->name << " range is "
             << rangeToString(a.offset, a.sec->size) << "\n>>> " << b.sec->name
             << " range is " << rangeToString(b.offset, b.sec->size);
  }
}

// Check for overlapping sections and address overflows.
//
// In this function we check that none of the output sections have overlapping
// file offsets. For SHF_ALLOC sections we also check that the load address
// ranges and the virtual address ranges don't overlap
template <class ELFT> void Writer<ELFT>::checkSections() {
  // First, check that section's VAs fit in available address space for target.
  for (OutputSection *os : ctx.outputSections)
    if ((os->addr + os->size < os->addr) ||
        (!ELFT::Is64Bits && os->addr + os->size > uint64_t(UINT32_MAX) + 1))
      Err(ctx) << "section " << os->name << " at 0x"
               << utohexstr(os->addr, true) << " of size 0x"
               << utohexstr(os->size, true)
               << " exceeds available address space";

  // Check for overlapping file offsets. In this case we need to skip any
  // section marked as SHT_NOBITS. These sections don't actually occupy space in
  // the file so Sec->Offset + Sec->Size can overlap with others. If --oformat
  // binary is specified only add SHF_ALLOC sections are added to the output
  // file so we skip any non-allocated sections in that case.
  std::vector<SectionOffset> fileOffs;
  for (OutputSection *sec : ctx.outputSections)
    if (sec->size > 0 && sec->type != SHT_NOBITS &&
        (!ctx.arg.oFormatBinary || (sec->flags & SHF_ALLOC)))
      fileOffs.push_back({sec, sec->offset});
  checkOverlap(ctx, "file", fileOffs, false);

  // When linking with -r there is no need to check for overlapping virtual/load
  // addresses since those addresses will only be assigned when the final
  // executable/shared object is created.
  if (ctx.arg.relocatable)
    return;

  // Checking for overlapping virtual and load addresses only needs to take
  // into account SHF_ALLOC sections since others will not be loaded.
  // Furthermore, we also need to skip SHF_TLS sections since these will be
  // mapped to other addresses at runtime and can therefore have overlapping
  // ranges in the file.
  std::vector<SectionOffset> vmas;
  for (OutputSection *sec : ctx.outputSections)
    if (sec->size > 0 && (sec->flags & SHF_ALLOC) && !(sec->flags & SHF_TLS))
      vmas.push_back({sec, sec->addr});
  checkOverlap(ctx, "virtual address", vmas, true);

  // Finally, check that the load addresses don't overlap. This will usually be
  // the same as the virtual addresses but can be different when using a linker
  // script with AT().
  std::vector<SectionOffset> lmas;
  for (OutputSection *sec : ctx.outputSections)
    if (sec->size > 0 && (sec->flags & SHF_ALLOC) && !(sec->flags & SHF_TLS))
      lmas.push_back({sec, sec->getLMA()});
  checkOverlap(ctx, "load address", lmas, false);
}

// The entry point address is chosen in the following ways.
//
// 1. the '-e' entry command-line option;
// 2. the ENTRY(symbol) command in a linker control script;
// 3. the value of the symbol _start, if present;
// 4. the number represented by the entry symbol, if it is a number;
// 5. the address 0.
static uint64_t getEntryAddr(Ctx &ctx) {
  // Case 1, 2 or 3
  if (Symbol *b = ctx.symtab->find(ctx.arg.entry))
    return b->getVA(ctx);

  // Case 4
  uint64_t addr;
  if (to_integer(ctx.arg.entry, addr))
    return addr;

  // Case 5
  if (ctx.arg.warnMissingEntry)
    Warn(ctx) << "cannot find entry symbol " << ctx.arg.entry
              << "; not setting start address";
  return 0;
}

static uint16_t getELFType(Ctx &ctx) {
  if (ctx.arg.isPic)
    return ET_DYN;
  if (ctx.arg.relocatable)
    return ET_REL;
  return ET_EXEC;
}

template <class ELFT> void Writer<ELFT>::writeHeader() {
  writeEhdr<ELFT>(ctx, ctx.bufferStart, *ctx.mainPart);
  writePhdrs<ELFT>(ctx.bufferStart + sizeof(Elf_Ehdr), *ctx.mainPart);

  auto *eHdr = reinterpret_cast<Elf_Ehdr *>(ctx.bufferStart);
  eHdr->e_type = getELFType(ctx);
  eHdr->e_entry = getEntryAddr(ctx);

  // If -z nosectionheader is specified, omit the section header table.
  if (!ctx.in.shStrTab)
    return;
  eHdr->e_shoff = sectionHeaderOff;

  // Write the section header table.
  //
  // The ELF header can only store numbers up to SHN_LORESERVE in the e_shnum
  // and e_shstrndx fields. When the value of one of these fields exceeds
  // SHN_LORESERVE ELF requires us to put sentinel values in the ELF header and
  // use fields in the section header at index 0 to store
  // the value. The sentinel values and fields are:
  // e_shnum = 0, SHdrs[0].sh_size = number of sections.
  // e_shstrndx = SHN_XINDEX, SHdrs[0].sh_link = .shstrtab section index.
  auto *sHdrs = reinterpret_cast<Elf_Shdr *>(ctx.bufferStart + eHdr->e_shoff);
  size_t num = ctx.outputSections.size() + 1;
  if (num >= SHN_LORESERVE)
    sHdrs->sh_size = num;
  else
    eHdr->e_shnum = num;

  uint32_t strTabIndex = ctx.in.shStrTab->getParent()->sectionIndex;
  if (strTabIndex >= SHN_LORESERVE) {
    sHdrs->sh_link = strTabIndex;
    eHdr->e_shstrndx = SHN_XINDEX;
  } else {
    eHdr->e_shstrndx = strTabIndex;
  }

  for (OutputSection *sec : ctx.outputSections)
    sec->writeHeaderTo<ELFT>(++sHdrs);
}

// Open a result file.
template <class ELFT> void Writer<ELFT>::openFile() {
  uint64_t maxSize = ctx.arg.is64 ? INT64_MAX : UINT32_MAX;
  if (fileSize != size_t(fileSize) || maxSize < fileSize) {
    std::string msg;
    raw_string_ostream s(msg);
    s << "output file too large: " << fileSize << " bytes\n"
      << "section sizes:\n";
    for (OutputSection *os : ctx.outputSections)
      s << os->name << ' ' << os->size << "\n";
    ErrAlways(ctx) << msg;
    return;
  }

  unlinkAsync(ctx.arg.outputFile);
  unsigned flags = 0;
  if (!ctx.arg.relocatable)
    flags |= FileOutputBuffer::F_executable;
  if (ctx.arg.mmapOutputFile)
    flags |= FileOutputBuffer::F_mmap;
  Expected<std::unique_ptr<FileOutputBuffer>> bufferOrErr =
      FileOutputBuffer::create(ctx.arg.outputFile, fileSize, flags);

  if (!bufferOrErr) {
    ErrAlways(ctx) << "failed to open " << ctx.arg.outputFile << ": "
                   << bufferOrErr.takeError();
    return;
  }
  buffer = std::move(*bufferOrErr);
  ctx.bufferStart = buffer->getBufferStart();
}

template <class ELFT> void Writer<ELFT>::writeSectionsBinary() {
  parallel::TaskGroup tg;
  for (OutputSection *sec : ctx.outputSections)
    if (sec->flags & SHF_ALLOC)
      sec->writeTo<ELFT>(ctx, ctx.bufferStart + sec->offset, tg);
}

static void fillTrap(std::array<uint8_t, 4> trapInstr, uint8_t *i,
                     uint8_t *end) {
  for (; i + 4 <= end; i += 4)
    memcpy(i, trapInstr.data(), 4);
}

// Fill the last page of executable segments with trap instructions
// instead of leaving them as zero. Even though it is not required by any
// standard, it is in general a good thing to do for security reasons.
//
// We'll leave other pages in segments as-is because the rest will be
// overwritten by output sections.
template <class ELFT> void Writer<ELFT>::writeTrapInstr() {
  for (Partition &part : ctx.partitions) {
    // Fill the last page.
    for (std::unique_ptr<PhdrEntry> &p : part.phdrs)
      if (p->p_type == PT_LOAD && (p->p_flags & PF_X))
        fillTrap(
            ctx.target->trapInstr,
            ctx.bufferStart + alignDown(p->firstSec->offset + p->p_filesz, 4),
            ctx.bufferStart + alignToPowerOf2(p->firstSec->offset + p->p_filesz,
                                              ctx.arg.maxPageSize));

    // Round up the file size of the last segment to the page boundary iff it is
    // an executable segment to ensure that other tools don't accidentally
    // trim the instruction padding (e.g. when stripping the file).
    PhdrEntry *last = nullptr;
    for (std::unique_ptr<PhdrEntry> &p : part.phdrs)
      if (p->p_type == PT_LOAD)
        last = p.get();

    if (last && (last->p_flags & PF_X)) {
      last->p_filesz = alignToPowerOf2(last->p_filesz, ctx.arg.maxPageSize);
      // p_memsz might be larger than the aligned p_filesz due to trailing BSS
      // sections. Don't decrease it.
      last->p_memsz = std::max(last->p_memsz, last->p_filesz);
    }
  }
}

// Write section contents to a mmap'ed file.
template <class ELFT> void Writer<ELFT>::writeSections() {
  llvm::TimeTraceScope timeScope("Write sections");

  {
    // In -r or --emit-relocs mode, write the relocation sections first as in
    // ELf_Rel targets we might find out that we need to modify the relocated
    // section while doing it.
    parallel::TaskGroup tg;
    for (OutputSection *sec : ctx.outputSections)
      if (isStaticRelSecType(sec->type))
        sec->writeTo<ELFT>(ctx, ctx.bufferStart + sec->offset, tg);
  }
  {
    parallel::TaskGroup tg;
    for (OutputSection *sec : ctx.outputSections)
      if (!isStaticRelSecType(sec->type))
        sec->writeTo<ELFT>(ctx, ctx.bufferStart + sec->offset, tg);
  }

  // Finally, check that all dynamic relocation addends were written correctly.
  if (ctx.arg.checkDynamicRelocs && ctx.arg.writeAddends) {
    for (OutputSection *sec : ctx.outputSections)
      if (isStaticRelSecType(sec->type))
        sec->checkDynRelAddends(ctx);
  }
}

// Computes a hash value of Data using a given hash function.
// In order to utilize multiple cores, we first split data into 1MB
// chunks, compute a hash for each chunk, and then compute a hash value
// of the hash values.
static void
computeHash(llvm::MutableArrayRef<uint8_t> hashBuf,
            llvm::ArrayRef<uint8_t> data,
            std::function<void(uint8_t *dest, ArrayRef<uint8_t> arr)> hashFn) {
  std::vector<ArrayRef<uint8_t>> chunks = split(data, 1024 * 1024);
  const size_t hashesSize = chunks.size() * hashBuf.size();
  std::unique_ptr<uint8_t[]> hashes(new uint8_t[hashesSize]);

  // Compute hash values.
  parallelFor(0, chunks.size(), [&](size_t i) {
    hashFn(hashes.get() + i * hashBuf.size(), chunks[i]);
  });

  // Write to the final output buffer.
  hashFn(hashBuf.data(), ArrayRef(hashes.get(), hashesSize));
}

template <class ELFT> void Writer<ELFT>::writeBuildId() {
  if (!ctx.mainPart->buildId || !ctx.mainPart->buildId->getParent())
    return;

  if (ctx.arg.buildId == BuildIdKind::Hexstring) {
    for (Partition &part : ctx.partitions)
      part.buildId->writeBuildId(ctx.arg.buildIdVector);
    return;
  }

  // Compute a hash of all sections of the output file.
  size_t hashSize = ctx.mainPart->buildId->hashSize;
  std::unique_ptr<uint8_t[]> buildId(new uint8_t[hashSize]);
  MutableArrayRef<uint8_t> output(buildId.get(), hashSize);
  llvm::ArrayRef<uint8_t> input{ctx.bufferStart, size_t(fileSize)};

  // Fedora introduced build ID as "approximation of true uniqueness across all
  // binaries that might be used by overlapping sets of people". It does not
  // need some security goals that some hash algorithms strive to provide, e.g.
  // (second-)preimage and collision resistance. In practice people use 'md5'
  // and 'sha1' just for different lengths. Implement them with the more
  // efficient BLAKE3.
  switch (ctx.arg.buildId) {
  case BuildIdKind::Fast:
    computeHash(output, input, [](uint8_t *dest, ArrayRef<uint8_t> arr) {
      write64le(dest, xxh3_64bits(arr));
    });
    break;
  case BuildIdKind::Md5:
    computeHash(output, input, [&](uint8_t *dest, ArrayRef<uint8_t> arr) {
      memcpy(dest, BLAKE3::hash<16>(arr).data(), hashSize);
    });
    break;
  case BuildIdKind::Sha1:
    computeHash(output, input, [&](uint8_t *dest, ArrayRef<uint8_t> arr) {
      memcpy(dest, BLAKE3::hash<20>(arr).data(), hashSize);
    });
    break;
  case BuildIdKind::Uuid:
    if (auto ec = llvm::getRandomBytes(buildId.get(), hashSize))
      ErrAlways(ctx) << "entropy source failure: " << ec.message();
    break;
  default:
    llvm_unreachable("unknown BuildIdKind");
  }
  for (Partition &part : ctx.partitions)
    part.buildId->writeBuildId(output);
}

template void elf::writeResult<ELF32LE>(Ctx &);
template void elf::writeResult<ELF32BE>(Ctx &);
template void elf::writeResult<ELF64LE>(Ctx &);
template void elf::writeResult<ELF64BE>(Ctx &);

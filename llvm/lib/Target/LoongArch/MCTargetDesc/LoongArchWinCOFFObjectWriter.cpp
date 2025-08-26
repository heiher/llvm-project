//===- LoongArchWinCOFFObjectWriter.cpp -----------------------*- C++ -*---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "MCTargetDesc/LoongArchFixupKinds.h"
#include "MCTargetDesc/LoongArchMCTargetDesc.h"
#include "llvm/BinaryFormat/COFF.h"
#include "llvm/MC/MCContext.h"
#include "llvm/MC/MCWinCOFFObjectWriter.h"

using namespace llvm;

namespace {

class LoongArchWinCOFFObjectWriter : public MCWinCOFFObjectTargetWriter {
public:
  LoongArchWinCOFFObjectWriter(bool Is64Bit);

  unsigned getRelocType(MCContext &Ctx, const MCValue &Target,
                        const MCFixup &Fixup, bool IsCrossSection,
                        const MCAsmBackend &MAB) const override;
};

} // end anonymous namespace

LoongArchWinCOFFObjectWriter::LoongArchWinCOFFObjectWriter(bool Is64Bit)
    : MCWinCOFFObjectTargetWriter(COFF::IMAGE_FILE_MACHINE_LOONGARCH64) {}

unsigned LoongArchWinCOFFObjectWriter::getRelocType(
    MCContext &Ctx, const MCValue &Target, const MCFixup &Fixup,
    bool IsCrossSection, const MCAsmBackend &MAB) const {
  // Determine the type of the relocation
  unsigned Kind = Fixup.getKind();
  switch (Kind) {
  default:
    Ctx.reportError(Fixup.getLoc(), "Unsupported relocation type");
    return COFF::IMAGE_REL_LARCH_ABSOLUTE;
  case FK_Data_1:
    Ctx.reportError(Fixup.getLoc(), "1-byte data relocations not supported");
    return COFF::IMAGE_REL_LARCH_ABSOLUTE;
  case FK_Data_2:
    Ctx.reportError(Fixup.getLoc(), "2-byte data relocations not supported");
    return COFF::IMAGE_REL_LARCH_ABSOLUTE;
  case FK_Data_4:
    return COFF::IMAGE_REL_LARCH_ADDR32;
  case FK_Data_8:
    return COFF::IMAGE_REL_LARCH_ADDR64;
  case LoongArch::fixup_loongarch_b16:
    return COFF::IMAGE_REL_LARCH_BRANCH16;
  case LoongArch::fixup_loongarch_b21:
    return COFF::IMAGE_REL_LARCH_BRANCH21;
  case LoongArch::fixup_loongarch_b26:
    return COFF::IMAGE_REL_LARCH_BRANCH26;
  case LoongArch::fixup_loongarch_abs_hi20:
    return COFF::IMAGE_REL_LARCH_ADDR_HI20;
  case LoongArch::fixup_loongarch_abs_lo12:
    return COFF::IMAGE_REL_LARCH_ADDR_LO12;
  case LoongArch::fixup_loongarch_abs64_lo20:
    return COFF::IMAGE_REL_LARCH_ADDR64_LO20;
  case LoongArch::fixup_loongarch_abs64_hi12:
    return COFF::IMAGE_REL_LARCH_ADDR64_HI12;
  case LoongArch::fixup_loongarch_pcala_hi20:
    return COFF::IMAGE_REL_LARCH_PCALA_HI20;
  case LoongArch::fixup_loongarch_pcala_lo12:
    return COFF::IMAGE_REL_LARCH_PCALA_LO12;
  }
}

std::unique_ptr<MCObjectTargetWriter>
llvm::createLoongArchWinCOFFObjectWriter(bool Is64Bit) {
  return std::make_unique<LoongArchWinCOFFObjectWriter>(Is64Bit);
}

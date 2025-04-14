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
    : MCWinCOFFObjectTargetWriter(Is64Bit
                                      ? COFF::IMAGE_FILE_MACHINE_LOONGARCH64
                                      : COFF::IMAGE_FILE_MACHINE_LOONGARCH32) {}

unsigned LoongArchWinCOFFObjectWriter::getRelocType(
    MCContext &Ctx, const MCValue &Target, const MCFixup &Fixup,
    bool IsCrossSection, const MCAsmBackend &MAB) const {
  // Determine the type of the relocation
  unsigned Kind = Fixup.getTargetKind();

  if (Kind >= FirstLiteralRelocationKind)
    return Kind - FirstLiteralRelocationKind;

  switch (Kind) {
  default:
    Ctx.reportError(Fixup.getLoc(), "Unsupported relocation type");
    return COFF::IMAGE_REL_LARCH_NONE;
  case FK_Data_1:
    Ctx.reportError(Fixup.getLoc(), "1-byte data relocations not supported");
    return COFF::IMAGE_REL_LARCH_NONE;
  case FK_Data_2:
    Ctx.reportError(Fixup.getLoc(), "2-byte data relocations not supported");
    return COFF::IMAGE_REL_LARCH_NONE;
  case FK_Data_4:
    return COFF::IMAGE_REL_LARCH_32;
  case FK_Data_8:
    return COFF::IMAGE_REL_LARCH_64;
  case LoongArch::fixup_loongarch_b16:
    return COFF::IMAGE_REL_LARCH_B16;
  case LoongArch::fixup_loongarch_b21:
    return COFF::IMAGE_REL_LARCH_B21;
  case LoongArch::fixup_loongarch_b26:
    return COFF::IMAGE_REL_LARCH_B26;
  case LoongArch::fixup_loongarch_abs_hi20:
    return COFF::IMAGE_REL_LARCH_ABS_HI20;
  case LoongArch::fixup_loongarch_abs_lo12:
    return COFF::IMAGE_REL_LARCH_ABS_LO12;
  case LoongArch::fixup_loongarch_abs64_lo20:
    return COFF::IMAGE_REL_LARCH_ABS64_LO20;
  case LoongArch::fixup_loongarch_abs64_hi12:
    return COFF::IMAGE_REL_LARCH_ABS64_HI12;
  case LoongArch::fixup_loongarch_tls_le_hi20:
    return COFF::IMAGE_REL_LARCH_TLS_LE_HI20;
  case LoongArch::fixup_loongarch_tls_le_lo12:
    return COFF::IMAGE_REL_LARCH_TLS_LE_LO12;
  case LoongArch::fixup_loongarch_tls_le64_lo20:
    return COFF::IMAGE_REL_LARCH_TLS_LE64_LO20;
  case LoongArch::fixup_loongarch_tls_le64_hi12:
    return COFF::IMAGE_REL_LARCH_TLS_LE64_HI12;
  case LoongArch::fixup_loongarch_call36:
    return COFF::IMAGE_REL_LARCH_CALL36;
    // TODO: Handle more fixup-kinds.
  }
}

std::unique_ptr<MCObjectTargetWriter>
llvm::createLoongArchWinCOFFObjectWriter(bool Is64Bit) {
  return std::make_unique<LoongArchWinCOFFObjectWriter>(Is64Bit);
}

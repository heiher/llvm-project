//===-- LoongArchMCTargetDesc.cpp - LoongArch Target Descriptions ---------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file provides LoongArch specific target descriptions.
//
//===----------------------------------------------------------------------===//

#include "LoongArchMCTargetDesc.h"
#include "LoongArchELFStreamer.h"
#include "LoongArchInstPrinter.h"
#include "LoongArchMCAsmInfo.h"
#include "LoongArchWinCOFFStreamer.h"
#include "TargetInfo/LoongArchTargetInfo.h"
#include "llvm/DebugInfo/CodeView/CodeView.h"
#include "llvm/MC/MCAsmBackend.h"
#include "llvm/MC/MCAsmInfo.h"
#include "llvm/MC/MCCodeEmitter.h"
#include "llvm/MC/MCDwarf.h"
#include "llvm/MC/MCInstrAnalysis.h"
#include "llvm/MC/MCInstrInfo.h"
#include "llvm/MC/MCObjectWriter.h"
#include "llvm/MC/MCRegisterInfo.h"
#include "llvm/MC/MCSubtargetInfo.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Support/Compiler.h"
#include <bitset>

#define GET_INSTRINFO_MC_DESC
#define ENABLE_INSTR_PREDICATE_VERIFIER
#include "LoongArchGenInstrInfo.inc"

#define GET_REGINFO_MC_DESC
#include "LoongArchGenRegisterInfo.inc"

#define GET_SUBTARGETINFO_MC_DESC
#include "LoongArchGenSubtargetInfo.inc"

using namespace llvm;
void LOONGARCH64_MC::initLLVMToCVRegMapping(MCRegisterInfo *MRI) {
  // Mapping from CodeView to MC register id.
  static const struct {
    codeview::RegisterId CVReg;
    MCPhysReg Reg;
  } RegMap[] = {
      {codeview::RegisterId::LOONGARCH64_ZERO, LoongArch::R0},
      {codeview::RegisterId::LOONGARCH64_RA, LoongArch::R1},
      {codeview::RegisterId::LOONGARCH64_TP, LoongArch::R2},
      {codeview::RegisterId::LOONGARCH64_SP, LoongArch::R3},
      {codeview::RegisterId::LOONGARCH64_A0, LoongArch::R4},
      {codeview::RegisterId::LOONGARCH64_A1, LoongArch::R5},
      {codeview::RegisterId::LOONGARCH64_A2, LoongArch::R6},
      {codeview::RegisterId::LOONGARCH64_A3, LoongArch::R7},
      {codeview::RegisterId::LOONGARCH64_A4, LoongArch::R8},
      {codeview::RegisterId::LOONGARCH64_A5, LoongArch::R9},
      {codeview::RegisterId::LOONGARCH64_A6, LoongArch::R10},
      {codeview::RegisterId::LOONGARCH64_A7, LoongArch::R11},
      {codeview::RegisterId::LOONGARCH64_T0, LoongArch::R12},
      {codeview::RegisterId::LOONGARCH64_T1, LoongArch::R13},
      {codeview::RegisterId::LOONGARCH64_T2, LoongArch::R14},
      {codeview::RegisterId::LOONGARCH64_T3, LoongArch::R15},
      {codeview::RegisterId::LOONGARCH64_T4, LoongArch::R16},
      {codeview::RegisterId::LOONGARCH64_T5, LoongArch::R17},
      {codeview::RegisterId::LOONGARCH64_T6, LoongArch::R18},
      {codeview::RegisterId::LOONGARCH64_T7, LoongArch::R19},
      {codeview::RegisterId::LOONGARCH64_T8, LoongArch::R20},
      {codeview::RegisterId::LOONGARCH64_R21, LoongArch::R21},
      {codeview::RegisterId::LOONGARCH64_FP, LoongArch::R22},
      {codeview::RegisterId::LOONGARCH64_S0, LoongArch::R23},
      {codeview::RegisterId::LOONGARCH64_S1, LoongArch::R24},
      {codeview::RegisterId::LOONGARCH64_S2, LoongArch::R25},
      {codeview::RegisterId::LOONGARCH64_S3, LoongArch::R26},
      {codeview::RegisterId::LOONGARCH64_S4, LoongArch::R27},
      {codeview::RegisterId::LOONGARCH64_S5, LoongArch::R28},
      {codeview::RegisterId::LOONGARCH64_S6, LoongArch::R29},
      {codeview::RegisterId::LOONGARCH64_S7, LoongArch::R30},
      {codeview::RegisterId::LOONGARCH64_S8, LoongArch::R31},
      {codeview::RegisterId::LOONGARCH64_F0, LoongArch::F0_64},
      {codeview::RegisterId::LOONGARCH64_F1, LoongArch::F1_64},
      {codeview::RegisterId::LOONGARCH64_F2, LoongArch::F2_64},
      {codeview::RegisterId::LOONGARCH64_F3, LoongArch::F3_64},
      {codeview::RegisterId::LOONGARCH64_F4, LoongArch::F4_64},
      {codeview::RegisterId::LOONGARCH64_F5, LoongArch::F5_64},
      {codeview::RegisterId::LOONGARCH64_F6, LoongArch::F6_64},
      {codeview::RegisterId::LOONGARCH64_F7, LoongArch::F7_64},
      {codeview::RegisterId::LOONGARCH64_F8, LoongArch::F8_64},
      {codeview::RegisterId::LOONGARCH64_F9, LoongArch::F9_64},
      {codeview::RegisterId::LOONGARCH64_F10, LoongArch::F10_64},
      {codeview::RegisterId::LOONGARCH64_F11, LoongArch::F11_64},
      {codeview::RegisterId::LOONGARCH64_F12, LoongArch::F12_64},
      {codeview::RegisterId::LOONGARCH64_F13, LoongArch::F13_64},
      {codeview::RegisterId::LOONGARCH64_F14, LoongArch::F14_64},
      {codeview::RegisterId::LOONGARCH64_F15, LoongArch::F15_64},
      {codeview::RegisterId::LOONGARCH64_F16, LoongArch::F16_64},
      {codeview::RegisterId::LOONGARCH64_F17, LoongArch::F17_64},
      {codeview::RegisterId::LOONGARCH64_F18, LoongArch::F18_64},
      {codeview::RegisterId::LOONGARCH64_F19, LoongArch::F19_64},
      {codeview::RegisterId::LOONGARCH64_F20, LoongArch::F20_64},
      {codeview::RegisterId::LOONGARCH64_F21, LoongArch::F21_64},
      {codeview::RegisterId::LOONGARCH64_F22, LoongArch::F22_64},
      {codeview::RegisterId::LOONGARCH64_F23, LoongArch::F23_64},
      {codeview::RegisterId::LOONGARCH64_F24, LoongArch::F24_64},
      {codeview::RegisterId::LOONGARCH64_F25, LoongArch::F25_64},
      {codeview::RegisterId::LOONGARCH64_F26, LoongArch::F26_64},
      {codeview::RegisterId::LOONGARCH64_F27, LoongArch::F27_64},
      {codeview::RegisterId::LOONGARCH64_F28, LoongArch::F28_64},
      {codeview::RegisterId::LOONGARCH64_F29, LoongArch::F29_64},
      {codeview::RegisterId::LOONGARCH64_F30, LoongArch::F30_64},
      {codeview::RegisterId::LOONGARCH64_F31, LoongArch::F31_64},
  };
  for (const auto &I : RegMap)
    MRI->mapLLVMRegToCVReg(I.Reg, static_cast<int>(I.CVReg));
}

static MCRegisterInfo *createLoongArchMCRegisterInfo(const Triple &TT) {
  MCRegisterInfo *X = new MCRegisterInfo();
  InitLoongArchMCRegisterInfo(X, LoongArch::R1);
  return X;
}

static MCInstrInfo *createLoongArchMCInstrInfo() {
  MCInstrInfo *X = new MCInstrInfo();
  InitLoongArchMCInstrInfo(X);
  return X;
}

static MCSubtargetInfo *
createLoongArchMCSubtargetInfo(const Triple &TT, StringRef CPU, StringRef FS) {
  if (CPU.empty() || CPU == "generic")
    CPU = TT.isArch64Bit() ? "generic-la64" : "generic-la32";
  return createLoongArchMCSubtargetInfoImpl(TT, CPU, /*TuneCPU*/ CPU, FS);
}

static MCAsmInfo *createLoongArchMCAsmInfo(const MCRegisterInfo &MRI,
                                           const Triple &TT,
                                           const MCTargetOptions &Options) {
  MCAsmInfo *MAI;
  if (TT.isOSBinFormatCOFF()) {
    MAI = new LoongArchMCAsmInfoMicrosoftCOFF(TT);
  } else {
    assert(TT.isOSBinFormatELF() && "Invalid target");
    MAI = new LoongArchMCAsmInfoELF(TT);
  }

  // Initial state of the frame pointer is sp(r3).
  unsigned SP = MRI.getDwarfRegNum(LoongArch::R3, true);
  MCCFIInstruction Inst = MCCFIInstruction::cfiDefCfa(nullptr, SP, 0);
  MAI->addInitialFrameState(Inst);

  return MAI;
}

static MCInstPrinter *createLoongArchMCInstPrinter(const Triple &T,
                                                   unsigned SyntaxVariant,
                                                   const MCAsmInfo &MAI,
                                                   const MCInstrInfo &MII,
                                                   const MCRegisterInfo &MRI) {
  return new LoongArchInstPrinter(MAI, MII, MRI);
}

static MCTargetStreamer *
createLoongArchObjectTargetStreamer(MCStreamer &S, const MCSubtargetInfo &STI) {
  if (STI.getTargetTriple().isOSBinFormatELF())
    return new LoongArchTargetELFStreamer(S, STI);
  if (STI.getTargetTriple().isOSBinFormatCOFF())
    return new LoongArchTargetWinCOFFStreamer(S);
  return nullptr;
}

static MCTargetStreamer *
createLoongArchAsmTargetStreamer(MCStreamer &S, formatted_raw_ostream &OS,
                                 MCInstPrinter *InstPrint) {
  return new LoongArchTargetAsmStreamer(S, OS);
}

namespace {

class LoongArchMCInstrAnalysis : public MCInstrAnalysis {
  int64_t GPRState[31] = {};
  std::bitset<31> GPRValidMask;

  static bool isGPR(MCRegister Reg) {
    return Reg >= LoongArch::R0 && Reg <= LoongArch::R31;
  }

  static unsigned getRegIndex(MCRegister Reg) {
    assert(isGPR(Reg) && Reg != LoongArch::R0 && "Invalid GPR reg");
    return Reg - LoongArch::R1;
  }

  void setGPRState(MCRegister Reg, std::optional<int64_t> Value) {
    if (Reg == LoongArch::R0)
      return;

    auto Index = getRegIndex(Reg);

    if (Value) {
      GPRState[Index] = *Value;
      GPRValidMask.set(Index);
    } else {
      GPRValidMask.reset(Index);
    }
  }

  std::optional<int64_t> getGPRState(MCRegister Reg) const {
    if (Reg == LoongArch::R0)
      return 0;

    auto Index = getRegIndex(Reg);

    if (GPRValidMask.test(Index))
      return GPRState[Index];
    return std::nullopt;
  }

public:
  explicit LoongArchMCInstrAnalysis(const MCInstrInfo *Info)
      : MCInstrAnalysis(Info) {}

  void resetState() override { GPRValidMask.reset(); }

  void updateState(const MCInst &Inst, uint64_t Addr) override {
    // Terminators mark the end of a basic block which means the sequentially
    // next instruction will be the first of another basic block and the current
    // state will typically not be valid anymore. For calls, we assume all
    // registers may be clobbered by the callee (TODO: should we take the
    // calling convention into account?).
    if (isTerminator(Inst) || isCall(Inst)) {
      resetState();
      return;
    }

    switch (Inst.getOpcode()) {
    default: {
      // Clear the state of all defined registers for instructions that we don't
      // explicitly support.
      auto NumDefs = Info->get(Inst.getOpcode()).getNumDefs();
      for (unsigned I = 0; I < NumDefs; ++I) {
        auto DefReg = Inst.getOperand(I).getReg();
        if (isGPR(DefReg))
          setGPRState(DefReg, std::nullopt);
      }
      break;
    }
    case LoongArch::PCADDU18I:
      setGPRState(
          Inst.getOperand(0).getReg(),
          Addr + SignExtend64<38>(
                     static_cast<uint64_t>(Inst.getOperand(1).getImm()) << 18));
      break;
    }
  }

  bool evaluateBranch(const MCInst &Inst, uint64_t Addr, uint64_t Size,
                      uint64_t &Target) const override {
    unsigned NumOps = Inst.getNumOperands();
    if ((isBranch(Inst) && !isIndirectBranch(Inst)) ||
        Inst.getOpcode() == LoongArch::BL) {
      Target = Addr + Inst.getOperand(NumOps - 1).getImm();
      return true;
    }

    if (Inst.getOpcode() == LoongArch::JIRL) {
      if (auto TargetRegState = getGPRState(Inst.getOperand(1).getReg())) {
        Target = *TargetRegState + Inst.getOperand(2).getImm();
        return true;
      }
      return false;
    }

    return false;
  }

  bool isTerminator(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isTerminator(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() == LoongArch::R0;
    }
  }

  bool isCall(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isCall(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() != LoongArch::R0;
    }
  }

  bool isReturn(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isReturn(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() == LoongArch::R0 &&
             Inst.getOperand(1).getReg() == LoongArch::R1;
    }
  }

  bool isBranch(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isBranch(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() == LoongArch::R0 &&
             Inst.getOperand(1).getReg() != LoongArch::R1;
    }
  }

  bool isUnconditionalBranch(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isUnconditionalBranch(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() == LoongArch::R0 &&
             Inst.getOperand(1).getReg() != LoongArch::R1;
    }
  }

  bool isIndirectBranch(const MCInst &Inst) const override {
    if (MCInstrAnalysis::isIndirectBranch(Inst))
      return true;

    switch (Inst.getOpcode()) {
    default:
      return false;
    case LoongArch::JIRL:
      return Inst.getOperand(0).getReg() == LoongArch::R0 &&
             Inst.getOperand(1).getReg() != LoongArch::R1;
    }
  }
};

} // end namespace

static MCInstrAnalysis *createLoongArchInstrAnalysis(const MCInstrInfo *Info) {
  return new LoongArchMCInstrAnalysis(Info);
}

namespace {
MCStreamer *createLoongArchELFStreamer(const Triple &T, MCContext &Context,
                                       std::unique_ptr<MCAsmBackend> &&MAB,
                                       std::unique_ptr<MCObjectWriter> &&MOW,
                                       std::unique_ptr<MCCodeEmitter> &&MCE) {
  return createLoongArchELFStreamer(Context, std::move(MAB), std::move(MOW),
                                    std::move(MCE));
}
} // end namespace

extern "C" LLVM_ABI LLVM_EXTERNAL_VISIBILITY void
LLVMInitializeLoongArchTargetMC() {
  for (Target *T : {&getTheLoongArch32Target(), &getTheLoongArch64Target()}) {
    TargetRegistry::RegisterMCRegInfo(*T, createLoongArchMCRegisterInfo);
    TargetRegistry::RegisterMCInstrInfo(*T, createLoongArchMCInstrInfo);
    TargetRegistry::RegisterMCSubtargetInfo(*T, createLoongArchMCSubtargetInfo);
    TargetRegistry::RegisterMCAsmInfo(*T, createLoongArchMCAsmInfo);
    TargetRegistry::RegisterMCCodeEmitter(*T, createLoongArchMCCodeEmitter);
    TargetRegistry::RegisterMCAsmBackend(*T, createLoongArchAsmBackend);
    TargetRegistry::RegisterMCInstPrinter(*T, createLoongArchMCInstPrinter);
    TargetRegistry::RegisterMCInstrAnalysis(*T, createLoongArchInstrAnalysis);
    TargetRegistry::RegisterELFStreamer(*T, createLoongArchELFStreamer);
    TargetRegistry::RegisterCOFFStreamer(*T, createLoongArchWinCOFFStreamer);
    TargetRegistry::RegisterObjectTargetStreamer(
        *T, createLoongArchObjectTargetStreamer);
    TargetRegistry::RegisterAsmTargetStreamer(*T,
                                              createLoongArchAsmTargetStreamer);
  }
}

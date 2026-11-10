//===- LoongArchRegRegAddrOrder.cpp - Order rj/rk of indexed load/store ---===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// The indexed (RegReg) loads and stores compute their address as rj + rk, so
// the two address operands can be exchanged freely. On LA664 and earlier
// micro-architectures they are not equivalent for timing: a value produced by
// a single-cycle integer instruction or by a reg+imm load is forwarded to rk
// one cycle later than to rj. For example
//
//   slli.d $a1, $a1, 3
//   ldx.d  $a0, $a0, $a1
//
// is one cycle slower than
//
//   slli.d $a1, $a1, 3
//   ldx.d  $a0, $a1, $a0
//
// This pass puts the address operand that arrives later in rj. How late an
// operand arrives is ranked by
//
//   1. the length of the loop-carried dependency from the result of the load
//      back to the operand, if there is one: this is what bounds the
//      throughput of pointer and index chasing loops;
//   2. otherwise the length of the dependency chain that leads to the operand
//      inside the machine trace through the block.
//
// The result of a call is assumed to be late: it is not available before the
// callee has returned, whereas what is computed around the call does not have
// to wait for it. Arguments, values that do not depend on any data
// (immediates, symbol addresses, GOT entries) and values defined outside of
// the innermost loop are treated as available early.
//
//===----------------------------------------------------------------------===//

#include "LoongArch.h"
#include "LoongArchSubtarget.h"
#include "llvm/ADT/SmallPtrSet.h"
#include "llvm/ADT/Statistic.h"
#include "llvm/CodeGen/MachineFunctionPass.h"
#include "llvm/CodeGen/MachineLoopInfo.h"
#include "llvm/CodeGen/MachineRegisterInfo.h"
#include "llvm/CodeGen/MachineTraceMetrics.h"
#include "llvm/CodeGen/TargetSchedule.h"
#include "llvm/InitializePasses.h"

using namespace llvm;

#define DEBUG_TYPE "loongarch-regreg-addr-order"
#define PASS_NAME "LoongArch RegReg address operand ordering"

STATISTIC(NumSwapped, "Number of indexed loads/stores with rj/rk swapped");

namespace {

class LoongArchRegRegAddrOrder : public MachineFunctionPass {
public:
  static char ID;

  LoongArchRegRegAddrOrder() : MachineFunctionPass(ID) {}

  bool runOnMachineFunction(MachineFunction &MF) override;

  void getAnalysisUsage(AnalysisUsage &AU) const override {
    AU.setPreservesCFG();
    AU.addRequired<MachineLoopInfoWrapperPass>();
    AU.addPreserved<MachineLoopInfoWrapperPass>();
    AU.addRequired<MachineTraceMetricsWrapperPass>();
    AU.addPreserved<MachineTraceMetricsWrapperPass>();
    MachineFunctionPass::getAnalysisUsage(AU);
  }

  StringRef getPassName() const override { return PASS_NAME; }

private:
  // When an address operand becomes available. An operand on a loop-carried
  // dependency through the load is always later than one that is not.
  struct Arrival {
    bool OnRecurrence = false;
    unsigned Cycles = 0;

    bool operator<(const Arrival &RHS) const {
      return std::tie(OnRecurrence, Cycles) <
             std::tie(RHS.OnRecurrence, RHS.Cycles);
    }
  };

  // Limits for the use-def walks.
  static constexpr unsigned RecurrenceBudget = 256;
  static constexpr unsigned MaxDepth = 8;
  static constexpr unsigned MaxChainDepth = 64;
  // A call takes a few cycles at the very least.
  static constexpr unsigned CallResultLatency = 8;

  const MachineRegisterInfo *MRI = nullptr;
  const MachineLoopInfo *MLI = nullptr;
  TargetSchedModel SchedModel;

  // State of the recurrence walk for the current instruction.
  const MachineInstr *Root = nullptr;
  const MachineLoop *RootLoop = nullptr;
  DenseMap<Register, std::optional<unsigned>> RecurrenceCache;
  SmallPtrSet<const MachineInstr *, 16> Visiting;
  unsigned Budget = 0;

  // The trace through the current block, and the chain lengths in it.
  std::optional<MachineTraceMetrics::Trace> Trace;
  DenseMap<Register, unsigned> ChainCache;

  bool isDataIndependent(Register Reg, unsigned Depth = 0) const;
  unsigned chainLength(Register Reg, unsigned Depth = 0);
  bool isForwardedLateToRk(Register Reg, const MachineLoop *L,
                           unsigned Depth = 0);
  unsigned getLatency(const MachineInstr &MI) const;
  std::optional<unsigned> recurrenceLength(Register Reg);
  Arrival getArrival(const MachineInstr &MI, unsigned OpIdx);
};

} // end anonymous namespace

char LoongArchRegRegAddrOrder::ID = 0;

INITIALIZE_PASS_BEGIN(LoongArchRegRegAddrOrder, DEBUG_TYPE, PASS_NAME, false,
                      false)
INITIALIZE_PASS_DEPENDENCY(MachineLoopInfoWrapperPass)
INITIALIZE_PASS_DEPENDENCY(MachineTraceMetricsWrapperPass)
INITIALIZE_PASS_END(LoongArchRegRegAddrOrder, DEBUG_TYPE, PASS_NAME, false,
                    false)

FunctionPass *llvm::createLoongArchRegRegAddrOrderPass() {
  return new LoongArchRegRegAddrOrder();
}

// The rj and rk operands of these instructions are operands 1 and 2.
static bool isRegRegLoadStore(unsigned Opc) {
  switch (Opc) {
  case LoongArch::LDX_B:
  case LoongArch::LDX_H:
  case LoongArch::LDX_W:
  case LoongArch::LDX_D:
  case LoongArch::LDX_BU:
  case LoongArch::LDX_HU:
  case LoongArch::LDX_WU:
  case LoongArch::STX_B:
  case LoongArch::STX_H:
  case LoongArch::STX_W:
  case LoongArch::STX_D:
  case LoongArch::FLDX_S:
  case LoongArch::FLDX_D:
  case LoongArch::FSTX_S:
  case LoongArch::FSTX_D:
  case LoongArch::VLDX:
  case LoongArch::VSTX:
  case LoongArch::XVLDX:
  case LoongArch::XVSTX:
    return true;
  default:
    return false;
  }
}

static bool isMul(unsigned Opc) {
  switch (Opc) {
  case LoongArch::MUL_W:
  case LoongArch::MULH_W:
  case LoongArch::MULH_WU:
  case LoongArch::MUL_D:
  case LoongArch::MULH_D:
  case LoongArch::MULH_DU:
  case LoongArch::MULW_D_W:
  case LoongArch::MULW_D_WU:
    return true;
  default:
    return false;
  }
}

static bool isDivRem(unsigned Opc) {
  switch (Opc) {
  case LoongArch::DIV_W:
  case LoongArch::DIV_WU:
  case LoongArch::DIV_D:
  case LoongArch::DIV_DU:
  case LoongArch::MOD_W:
  case LoongArch::MOD_WU:
  case LoongArch::MOD_D:
  case LoongArch::MOD_DU:
    return true;
  default:
    return false;
  }
}

// TODO: Rely on the scheduling model once there is one for these cores. Until
// then every instruction but a load has the default latency of one cycle,
// which is too far off for multiplications and divisions.
unsigned LoongArchRegRegAddrOrder::getLatency(const MachineInstr &MI) const {
  if (MI.isTransient())
    return 0;
  if (!SchedModel.hasInstrSchedModel()) {
    if (isMul(MI.getOpcode()))
      return 4;
    if (isDivRem(MI.getOpcode()))
      return 12;
  }
  return SchedModel.computeInstrLatency(&MI);
}

// Return true if Reg is computed from immediates and symbols only: constant
// materialization, symbol addresses and loads of GOT entries. Such a value
// has no data dependency, so it is ready as soon as it has been dispatched.
bool LoongArchRegRegAddrOrder::isDataIndependent(Register Reg,
                                                 unsigned Depth) const {
  if (Reg == LoongArch::R0)
    return true;
  if (!Reg.isVirtual() || Depth == MaxDepth)
    return false;
  const MachineInstr *Def = MRI->getVRegDef(Reg);
  if (!Def || Def->isPHI() || Def->isCall() || Def->mayStore() ||
      Def->hasUnmodeledSideEffects())
    return false;
  if (Def->mayLoad() && !Def->isDereferenceableInvariantLoad())
    return false;
  return all_of(Def->all_uses(), [&](const MachineOperand &MO) {
    return isDataIndependent(MO.getReg(), Depth + 1);
  });
}

// Return true if MI copies a result of a call out of its physical register.
static bool isCallResultCopy(const MachineInstr &MI) {
  if (!MI.isCopy() || !MI.getOperand(1).getReg().isPhysical())
    return false;
  // The copies follow the call, with only the stack adjustment in between.
  for (MachineBasicBlock::const_reverse_iterator
           I = std::next(MI.getReverseIterator()),
           E = MI.getParent()->rend();
       I != E; ++I) {
    const MachineInstr &Prev = *I;
    if (Prev.isCall())
      return true;
    if (!Prev.isCopy() && Prev.getOpcode() != LoongArch::ADJCALLSTACKUP)
      return false;
  }
  return false;
}

// Return the length in cycles of the longest dependency chain that leads to
// Reg inside the trace through the block of Root.
unsigned LoongArchRegRegAddrOrder::chainLength(Register Reg, unsigned Depth) {
  if (!Reg.isVirtual() || Depth == MaxChainDepth)
    return 0;
  const MachineInstr *Def = MRI->getVRegDef(Reg);
  if (!Def || Def->isPHI())
    return 0;
  auto It = ChainCache.find(Reg);
  if (It != ChainCache.end())
    return It->second;

  unsigned Longest = 0;
  if (isCallResultCopy(*Def)) {
    Longest = CallResultLatency;
  } else if (Trace->isDepInTrace(*Def, *Root) && !isDataIndependent(Reg)) {
    for (const MachineOperand &MO : Def->all_uses())
      Longest = std::max(Longest, chainLength(MO.getReg(), Depth + 1));
    Longest += getLatency(*Def);
  }
  return ChainCache[Reg] = Longest;
}

// Return true if the producer of Reg pays the extra cycle when its result is
// consumed through rk. This is the case for single-cycle integer instructions
// and for reg+imm loads. It is not the case for indexed loads, for
// multiplications and divisions, and for moves from the FP/SIMD registers.
// Values that are available early anyway never pay it.
bool LoongArchRegRegAddrOrder::isForwardedLateToRk(Register Reg,
                                                   const MachineLoop *L,
                                                   unsigned Depth) {
  if (!Reg.isVirtual() || Depth == MaxDepth)
    return false;
  const MachineInstr *Def = MRI->getVRegDef(Reg);
  if (!Def || Def->isCall())
    return false;
  // Loop invariant values were computed long ago.
  if (L && !L->contains(Def->getParent()))
    return false;
  if (isDataIndependent(Reg))
    return false;

  if (Def->isCopy()) {
    // An argument or the result of a call: the producer is unknown, and it
    // may well be the last instruction before the call or the return.
    Register Src = Def->getOperand(1).getReg();
    return Src.isPhysical() || isForwardedLateToRk(Src, L, Depth + 1);
  }
  if (Def->isPHI()) {
    for (unsigned I = 1, E = Def->getNumOperands(); I != E; I += 2)
      if (isForwardedLateToRk(Def->getOperand(I).getReg(), L, Depth + 1))
        return true;
    return false;
  }

  if (isRegRegLoadStore(Def->getOpcode()) || isMul(Def->getOpcode()) ||
      isDivRem(Def->getOpcode()))
    return false;
  if (Def->mayLoad())
    return true;
  // Moves from FP/SIMD registers and other cross-domain instructions.
  return all_of(Def->all_uses(), [&](const MachineOperand &MO) {
    Register R = MO.getReg();
    if (R.isPhysical())
      return LoongArch::GPRRegClass.contains(R);
    return LoongArch::GPRRegClass.hasSubClassEq(MRI->getRegClass(R));
  });
}

// Return the length in cycles of the longest dependency chain inside RootLoop
// that leads from the result of Root to Reg, if there is one.
std::optional<unsigned>
LoongArchRegRegAddrOrder::recurrenceLength(Register Reg) {
  if (!Reg.isVirtual())
    return std::nullopt;
  const MachineInstr *Def = MRI->getVRegDef(Reg);
  if (!Def)
    return std::nullopt;
  if (Def == Root)
    return 0;
  if (!RootLoop->contains(Def->getParent()))
    return std::nullopt;

  auto It = RecurrenceCache.find(Reg);
  if (It != RecurrenceCache.end())
    return It->second;
  // Do not cache the result of a walk that was cut short.
  if (Budget == 0 || !Visiting.insert(Def).second)
    return std::nullopt;
  --Budget;

  std::optional<unsigned> Longest;
  auto Visit = [&](Register R) {
    if (std::optional<unsigned> Len = recurrenceLength(R))
      Longest = std::max(Longest.value_or(0), *Len);
  };
  if (Def->isPHI()) {
    for (unsigned I = 1, E = Def->getNumOperands(); I != E; I += 2)
      if (RootLoop->contains(Def->getOperand(I + 1).getMBB()))
        Visit(Def->getOperand(I).getReg());
  } else {
    for (const MachineOperand &MO : Def->all_uses())
      Visit(MO.getReg());
  }
  Visiting.erase(Def);

  if (Longest)
    *Longest += getLatency(*Def);
  if (Budget != 0)
    RecurrenceCache[Reg] = Longest;
  return Longest;
}

LoongArchRegRegAddrOrder::Arrival
LoongArchRegRegAddrOrder::getArrival(const MachineInstr &MI, unsigned OpIdx) {
  Register Reg = MI.getOperand(OpIdx).getReg();
  if (!Reg.isVirtual())
    return {};

  // Only a load can feed its own address.
  if (RootLoop && MI.getNumExplicitDefs() == 1)
    if (std::optional<unsigned> Len = recurrenceLength(Reg))
      return {true, *Len};

  return {false, chainLength(Reg)};
}

bool LoongArchRegRegAddrOrder::runOnMachineFunction(MachineFunction &MF) {
  if (skipFunction(MF.getFunction()))
    return false;

  MRI = &MF.getRegInfo();
  if (!MRI->isSSA())
    return false;
  MLI = &getAnalysis<MachineLoopInfoWrapperPass>().getLI();
  SchedModel.init(&MF.getSubtarget());
  MachineTraceMetrics::Ensemble *Traces =
      getAnalysis<MachineTraceMetricsWrapperPass>().getMTM().getEnsemble(
          MachineTraceStrategy::TS_MinInstrCount);

  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    RootLoop = MLI->getLoopFor(&MBB);
    Trace.reset();
    ChainCache.clear();

    for (MachineInstr &MI : MBB) {
      if (!isRegRegLoadStore(MI.getOpcode()))
        continue;
      MachineOperand &Rj = MI.getOperand(1);
      MachineOperand &Rk = MI.getOperand(2);
      if (!Rj.isReg() || !Rk.isReg() || Rj.getReg() == Rk.getReg())
        continue;

      if (!Trace)
        Trace.emplace(Traces->getTrace(&MBB));
      Root = &MI;
      RecurrenceCache.clear();
      Visiting.clear();
      Budget = RecurrenceBudget;
      Arrival ArrJ = getArrival(MI, 1);
      Arrival ArrK = getArrival(MI, 2);

      // The address is ready when both operands have arrived, with the
      // operand in rk possibly taking one more cycle.
      auto AddrReady = [&](Arrival InRj, Arrival InRk, Register RkReg) {
        if (isForwardedLateToRk(RkReg, RootLoop))
          ++InRk.Cycles;
        return std::max(InRj, InRk);
      };
      if (!(AddrReady(ArrK, ArrJ, Rj.getReg()) <
            AddrReady(ArrJ, ArrK, Rk.getReg())))
        continue;

      LLVM_DEBUG(dbgs() << "Swapping rj and rk of: " << MI);
      Register RegJ = Rj.getReg(), RegK = Rk.getReg();
      bool KillJ = Rj.isKill(), KillK = Rk.isKill();
      Rj.setReg(RegK);
      Rj.setIsKill(KillK);
      Rk.setReg(RegJ);
      Rk.setIsKill(KillJ);
      ++NumSwapped;
      Changed = true;
    }
  }
  return Changed;
}

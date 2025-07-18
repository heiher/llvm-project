//===- CoroCleanup.cpp - Coroutine Cleanup Pass ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "llvm/Transforms/Coroutines/CoroCleanup.h"
#include "CoroInternal.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Transforms/Scalar/SimplifyCFG.h"

using namespace llvm;

#define DEBUG_TYPE "coro-cleanup"

namespace {
// Created on demand if CoroCleanup pass has work to do.
struct Lowerer : coro::LowererBase {
  IRBuilder<> Builder;
  Lowerer(Module &M) : LowererBase(M), Builder(Context) {}
  bool lower(Function &F);
};
}

static void lowerSubFn(IRBuilder<> &Builder, CoroSubFnInst *SubFn) {
  Builder.SetInsertPoint(SubFn);
  Value *FramePtr = SubFn->getFrame();
  int Index = SubFn->getIndex();

  auto *FrameTy = StructType::get(SubFn->getContext(),
                                  {Builder.getPtrTy(), Builder.getPtrTy()});

  Builder.SetInsertPoint(SubFn);
  auto *Gep = Builder.CreateConstInBoundsGEP2_32(FrameTy, FramePtr, 0, Index);
  auto *Load = Builder.CreateLoad(FrameTy->getElementType(Index), Gep);

  SubFn->replaceAllUsesWith(Load);
}

bool Lowerer::lower(Function &F) {
  bool IsPrivateAndUnprocessed = F.isPresplitCoroutine() && F.hasLocalLinkage();
  bool Changed = false;

  for (Instruction &I : llvm::make_early_inc_range(instructions(F))) {
    if (auto *II = dyn_cast<IntrinsicInst>(&I)) {
      switch (II->getIntrinsicID()) {
      default:
        continue;
      case Intrinsic::coro_begin:
      case Intrinsic::coro_begin_custom_abi:
        II->replaceAllUsesWith(II->getArgOperand(1));
        break;
      case Intrinsic::coro_free:
        II->replaceAllUsesWith(II->getArgOperand(1));
        break;
      case Intrinsic::coro_alloc:
        II->replaceAllUsesWith(ConstantInt::getTrue(Context));
        break;
      case Intrinsic::coro_async_resume:
        II->replaceAllUsesWith(
            ConstantPointerNull::get(cast<PointerType>(I.getType())));
        break;
      case Intrinsic::coro_id:
      case Intrinsic::coro_id_retcon:
      case Intrinsic::coro_id_retcon_once:
      case Intrinsic::coro_id_async:
        II->replaceAllUsesWith(ConstantTokenNone::get(Context));
        break;
      case Intrinsic::coro_subfn_addr:
        lowerSubFn(Builder, cast<CoroSubFnInst>(II));
        break;
      case Intrinsic::coro_end:
      case Intrinsic::coro_suspend_retcon:
        if (IsPrivateAndUnprocessed) {
          II->replaceAllUsesWith(PoisonValue::get(II->getType()));
        } else
          continue;
        break;
      case Intrinsic::coro_async_size_replace:
        auto *Target = cast<ConstantStruct>(
            cast<GlobalVariable>(II->getArgOperand(0)->stripPointerCasts())
                ->getInitializer());
        auto *Source = cast<ConstantStruct>(
            cast<GlobalVariable>(II->getArgOperand(1)->stripPointerCasts())
                ->getInitializer());
        auto *TargetSize = Target->getOperand(1);
        auto *SourceSize = Source->getOperand(1);
        if (TargetSize->isElementWiseEqual(SourceSize)) {
          break;
        }
        auto *TargetRelativeFunOffset = Target->getOperand(0);
        auto *NewFuncPtrStruct = ConstantStruct::get(
            Target->getType(), TargetRelativeFunOffset, SourceSize);
        Target->replaceAllUsesWith(NewFuncPtrStruct);
        break;
      }
      II->eraseFromParent();
      Changed = true;
    }
  }

  return Changed;
}

static bool declaresCoroCleanupIntrinsics(const Module &M) {
  return coro::declaresIntrinsics(
      M, {Intrinsic::coro_alloc, Intrinsic::coro_begin,
          Intrinsic::coro_subfn_addr, Intrinsic::coro_free, Intrinsic::coro_id,
          Intrinsic::coro_id_retcon, Intrinsic::coro_id_async,
          Intrinsic::coro_id_retcon_once, Intrinsic::coro_async_size_replace,
          Intrinsic::coro_async_resume, Intrinsic::coro_begin_custom_abi});
}

PreservedAnalyses CoroCleanupPass::run(Module &M,
                                       ModuleAnalysisManager &MAM) {
  if (!declaresCoroCleanupIntrinsics(M))
    return PreservedAnalyses::all();

  FunctionAnalysisManager &FAM =
      MAM.getResult<FunctionAnalysisManagerModuleProxy>(M).getManager();

  FunctionPassManager FPM;
  FPM.addPass(SimplifyCFGPass());

  PreservedAnalyses FuncPA;
  FuncPA.preserveSet<CFGAnalyses>();

  Lowerer L(M);
  for (auto &F : M) {
    if (L.lower(F)) {
      FAM.invalidate(F, FuncPA);
      FPM.run(F, FAM);
    }
  }

  return PreservedAnalyses::none();
}

//===- MemRefToEmitC.cpp - MemRef to EmitC conversion ---------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements a pass to convert memref ops into emitc ops.
//
//===----------------------------------------------------------------------===//

#include "mlir/Conversion/MemRefToEmitC/MemRefToEmitCPass.h"

#include "mlir/Conversion/MemRefToEmitC/MemRefToEmitC.h"
#include "mlir/Dialect/EmitC/IR/EmitC.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/IR/Attributes.h"
#include "mlir/Pass/Pass.h"
#include "mlir/Transforms/DialectConversion.h"

namespace mlir {
#define GEN_PASS_DEF_CONVERTMEMREFTOEMITC
#include "mlir/Conversion/Passes.h.inc"
} // namespace mlir

using namespace mlir;

namespace {
struct ConvertMemRefToEmitCPass
    : public impl::ConvertMemRefToEmitCBase<ConvertMemRefToEmitCPass> {
  using Base::Base;
  void runOnOperation() override {
    TypeConverter converter;
    ConvertMemRefToEmitCOptions options;
    options.lowerToCpp = this->lowerToCpp;
    // Fallback for other types.
    converter.addConversion([](Type type) -> std::optional<Type> {
      if (!emitc::isSupportedEmitCType(type))
        return {};
      return type;
    });

    populateMemRefToEmitCTypeConversion(converter);

    RewritePatternSet patterns(&getContext());
    populateMemRefToEmitCConversionPatterns(patterns, converter);

    ConversionTarget target(getContext());
    target.addIllegalDialect<memref::MemRefDialect>();
    target.addLegalDialect<emitc::EmitCDialect>();

    if (failed(applyPartialConversion(getOperation(), target,
                                      std::move(patterns))))
      return signalPassFailure();

    mlir::ModuleOp module = getOperation();
    module.walk([&](mlir::emitc::CallOpaqueOp callOp) {
      if (callOp.getCallee() != alignedAllocFunctionName &&
          callOp.getCallee() != mallocFunctionName) {
        return mlir::WalkResult::advance();
      }

      for (auto &op : *module.getBody()) {
        emitc::IncludeOp includeOp = llvm::dyn_cast<mlir::emitc::IncludeOp>(op);
        if (!includeOp) {
          continue;
        }
        if (includeOp.getIsStandardInclude() &&
            ((options.lowerToCpp &&
              includeOp.getInclude() == cppStandardLibraryHeader) ||
             (!options.lowerToCpp &&
              includeOp.getInclude() == cStandardLibraryHeader))) {
          return mlir::WalkResult::interrupt();
        }
      }

      mlir::OpBuilder builder(module.getBody(), module.getBody()->begin());
      StringAttr includeAttr =
          builder.getStringAttr(options.lowerToCpp ? cppStandardLibraryHeader
                                                   : cStandardLibraryHeader);
      builder.create<mlir::emitc::IncludeOp>(
          module.getLoc(), includeAttr,
          /*is_standard_include=*/builder.getUnitAttr());
      return mlir::WalkResult::interrupt();
    });
  }
};
} // namespace

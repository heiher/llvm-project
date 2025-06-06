; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=powerpc64-- -verify-machineinstrs \
; RUN:   -ppc-asm-full-reg-names < %s | FileCheck %s
%struct.e.0.1.2.3.12.29 = type { [10 x i32] }

define dso_local void @g(ptr %agg.result) local_unnamed_addr #0 {
; CHECK-LABEL: g:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    mflr r0
; CHECK-NEXT:    stdu r1, -112(r1)
; CHECK-NEXT:    std r0, 128(r1)
; CHECK-NEXT:    bl i
; CHECK-NEXT:    nop
; CHECK-NEXT:    addis r4, r2, g@toc@ha
; CHECK-NEXT:    addi r5, r4, g@toc@l
; CHECK-NEXT:    ld r6, 16(r5)
; CHECK-NEXT:    std r6, 16(r3)
; CHECK-NEXT:    ld r4, g@toc@l(r4)
; CHECK-NEXT:    std r4, 0(r3)
; CHECK-NEXT:    rldicl r4, r4, 32, 32
; CHECK-NEXT:    ld r7, 8(r5)
; CHECK-NEXT:    std r7, 8(r3)
; CHECK-NEXT:    ld r7, 24(r5)
; CHECK-NEXT:    std r7, 24(r3)
; CHECK-NEXT:    ld r5, 32(r5)
; CHECK-NEXT:    stwbrx r4, 0, r3
; CHECK-NEXT:    li r4, 20
; CHECK-NEXT:    std r5, 32(r3)
; CHECK-NEXT:    stwbrx r6, r3, r4
; CHECK-NEXT:    addi r1, r1, 112
; CHECK-NEXT:    ld r0, 16(r1)
; CHECK-NEXT:    mtlr r0
; CHECK-NEXT:    blr
entry:
  %call = tail call signext i32 @i()
  %conv = sext i32 %call to i64
  %0 = inttoptr i64 %conv to ptr
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 4 dereferenceable(40) %0, ptr nonnull align 4 dereferenceable(40) @g, i64 40, i1 false)
  %1 = inttoptr i64 %conv to ptr
  %2 = load i32, ptr %1, align 4
  %rev.i = tail call i32 @llvm.bswap.i32(i32 %2)
  store i32 %rev.i, ptr %1, align 4
  %incdec.ptr.i.4 = getelementptr inbounds i32, ptr %1, i64 5
  %3 = load i32, ptr %incdec.ptr.i.4, align 4
  %rev.i.5 = tail call i32 @llvm.bswap.i32(i32 %3)
  store i32 %rev.i.5, ptr %incdec.ptr.i.4, align 4
  ret void
}

declare i32 @i(...) local_unnamed_addr

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #1

; Function Attrs: nounwind readnone speculatable willreturn
declare i32 @llvm.bswap.i32(i32)

attributes #0 = { nounwind }

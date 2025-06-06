; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --version 5
; RUN: opt -S -passes='require<profile-summary>,function(codegenprepare)' %s | FileCheck %s

target triple = "x86_64-unknown-linux"

declare i1 @cond(float)

define void @scaled_reg_does_not_dominate_insert_point(ptr %src) {
; CHECK-LABEL: define void @scaled_reg_does_not_dominate_insert_point(
; CHECK-SAME: ptr [[SRC:%.*]]) {
; CHECK-NEXT:  [[BB:.*]]:
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ 0, %[[BB]] ], [ [[IV_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[IV_NEXT]] = add i64 [[IV]], 1
; CHECK-NEXT:    [[SUNKADDR2:%.*]] = mul i64 [[IV_NEXT]], 2
; CHECK-NEXT:    [[SUNKADDR3:%.*]] = getelementptr i8, ptr [[SRC]], i64 [[SUNKADDR2]]
; CHECK-NEXT:    [[SUNKADDR4:%.*]] = getelementptr i8, ptr [[SUNKADDR3]], i64 6
; CHECK-NEXT:    [[L_0:%.*]] = load float, ptr [[SUNKADDR4]], align 4
; CHECK-NEXT:    [[SUNKADDR:%.*]] = mul i64 [[IV]], 2
; CHECK-NEXT:    [[SUNKADDR1:%.*]] = getelementptr i8, ptr [[SRC]], i64 [[SUNKADDR]]
; CHECK-NEXT:    [[L_1:%.*]] = load float, ptr [[SUNKADDR1]], align 4
; CHECK-NEXT:    [[TMP0:%.*]] = call i1 @cond(float [[L_0]])
; CHECK-NEXT:    [[C:%.*]] = call i1 @cond(float [[L_1]])
; CHECK-NEXT:    br i1 [[C]], label %[[LOOP]], label %[[EXIT:.*]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    ret void
;
bb:
  %gep.base = getelementptr i8, ptr %src, i64 8
  br label %loop

loop:
  %iv = phi i64 [ 0, %bb ], [ %iv.next, %loop ]
  %iv.shl = shl i64 %iv, 1
  %gep.shl = getelementptr i8, ptr %gep.base, i64 %iv.shl
  %gep.sub = getelementptr i8, ptr %gep.shl, i64 -8
  %iv.next = add i64 %iv, 1
  %l.0 = load float, ptr %gep.shl, align 4
  %l.1 = load float, ptr %gep.sub, align 4
  call i1 @cond(float %l.0)
  %c = call i1 @cond(float %l.1)
  br i1 %c, label %loop, label %exit

exit:
  ret void
}

define void @check_dt_after_modifying_cfg(ptr %dst, i64 %x, i8 %y, i8 %z) {
; CHECK-LABEL: define void @check_dt_after_modifying_cfg(
; CHECK-SAME: ptr [[DST:%.*]], i64 [[X:%.*]], i8 [[Y:%.*]], i8 [[Z:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    [[OFFSET:%.*]] = lshr i64 [[X]], 2
; CHECK-NEXT:    [[SEL_FROZEN:%.*]] = freeze i8 [[Z]]
; CHECK-NEXT:    [[CMP:%.*]] = icmp slt i8 [[SEL_FROZEN]], 0
; CHECK-NEXT:    br i1 [[CMP]], label %[[SELECT_END:.*]], label %[[SELECT_FALSE_SINK:.*]]
; CHECK:       [[SELECT_FALSE_SINK]]:
; CHECK-NEXT:    [[SMIN:%.*]] = tail call i8 @llvm.smin.i8(i8 [[Y]], i8 0)
; CHECK-NEXT:    br label %[[SELECT_END]]
; CHECK:       [[SELECT_END]]:
; CHECK-NEXT:    [[SEL:%.*]] = phi i8 [ 0, %[[ENTRY]] ], [ [[SMIN]], %[[SELECT_FALSE_SINK]] ]
; CHECK-NEXT:    [[SUNKADDR:%.*]] = getelementptr i8, ptr [[DST]], i64 [[OFFSET]]
; CHECK-NEXT:    store i8 [[SEL]], ptr [[SUNKADDR]], align 1
; CHECK-NEXT:    ret void
;
entry:
  %offset = lshr i64 %x, 2
  %gep.dst = getelementptr i8, ptr %dst, i64 %offset
  %smin = tail call i8 @llvm.smin.i8(i8 %y, i8 0)
  %cmp = icmp slt i8 %z, 0
  %sel = select i1 %cmp, i8 0, i8 %smin
  store i8 %sel, ptr %gep.dst, align 1
  ret void
}

declare i8 @llvm.smin.i8(i8, i8) #0

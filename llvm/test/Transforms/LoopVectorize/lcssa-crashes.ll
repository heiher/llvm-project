; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -passes=loop-vectorize -force-vector-interleave=1 -force-vector-width=4 -S %s | FileCheck %s

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"

define void @test() {
; CHECK-LABEL: @test(
; CHECK-NEXT:    br label [[FOR_BODY_LR_PH_I_I_I:%.*]]
; CHECK:       for.body.lr.ph.i.i.i:
; CHECK-NEXT:    br i1 true, label [[SCALAR_PH:%.*]], label [[VECTOR_PH:%.*]]
; CHECK:       vector.ph:
; CHECK-NEXT:    br label [[VECTOR_BODY:%.*]]
; CHECK:       vector.body:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, [[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], [[VECTOR_BODY]] ]
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 4
; CHECK-NEXT:    [[TMP1:%.*]] = icmp eq i64 [[INDEX_NEXT]], 0
; CHECK-NEXT:    br i1 [[TMP1]], label [[MIDDLE_BLOCK:%.*]], label [[VECTOR_BODY]], !llvm.loop [[LOOP0:![0-9]+]]
; CHECK:       middle.block:
; CHECK-NEXT:    br i1 false, label [[FOR_END_I_I_I:%.*]], label [[SCALAR_PH]]
; CHECK:       scalar.ph:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ 0, [[MIDDLE_BLOCK]] ], [ 0, [[FOR_BODY_LR_PH_I_I_I]] ]
; CHECK-NEXT:    br label [[FOR_BODY_I_I_I:%.*]]
; CHECK:       for.body.i.i.i:
; CHECK-NEXT:    [[INDVARS_IV:%.*]] = phi i64 [ [[INDVARS_IV_NEXT:%.*]], [[FOR_INC_I_I_I:%.*]] ], [ [[BC_RESUME_VAL]], [[SCALAR_PH]] ]
; CHECK-NEXT:    br label [[FOR_INC_I_I_I]]
; CHECK:       for.inc.i.i.i:
; CHECK-NEXT:    [[INDVARS_IV_NEXT]] = add i64 [[INDVARS_IV]], 1
; CHECK-NEXT:    [[LFTR_WIDEIV:%.*]] = trunc i64 [[INDVARS_IV_NEXT]] to i32
; CHECK-NEXT:    [[EXITCOND:%.*]] = icmp ne i32 [[LFTR_WIDEIV]], undef
; CHECK-NEXT:    br i1 [[EXITCOND]], label [[FOR_BODY_I_I_I]], label [[FOR_END_I_I_I]], !llvm.loop [[LOOP3:![0-9]+]]
; CHECK:       for.end.i.i.i:
; CHECK-NEXT:    [[LCSSA:%.*]] = phi ptr [ undef, [[FOR_INC_I_I_I]] ], [ undef, [[MIDDLE_BLOCK]] ]
; CHECK-NEXT:    unreachable
;
  br label %for.body.lr.ph.i.i.i

for.body.lr.ph.i.i.i:
  br label %for.body.i.i.i

for.body.i.i.i:
  %indvars.iv = phi i64 [ %indvars.iv.next, %for.inc.i.i.i ], [ 0, %for.body.lr.ph.i.i.i ]
  br label %for.inc.i.i.i

for.inc.i.i.i:
  %indvars.iv.next = add i64 %indvars.iv, 1
  %lftr.wideiv = trunc i64 %indvars.iv.next to i32
  %exitcond = icmp ne i32 %lftr.wideiv, undef
  br i1 %exitcond, label %for.body.i.i.i, label %for.end.i.i.i

for.end.i.i.i:
  %lcssa = phi ptr [ undef, %for.inc.i.i.i ]
  unreachable
}

; PR16139
define void @test2(ptr %x) {
; CHECK-LABEL: @test2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    indirectbr ptr [[X:%.*]], [label [[L0:%.*]], label %L1]
; CHECK:       L0:
; CHECK-NEXT:    br label [[L0]]
; CHECK:       L1:
; CHECK-NEXT:    ret void
;
entry:
  indirectbr ptr %x, [ label %L0, label %L1 ]

L0:
  br label %L0

L1:
  ret void
}

; This loop has different uniform instructions before and after LCSSA.
define void @test3() {
; CHECK-LABEL: @test3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[ADD41:%.*]] = add i32 undef, undef
; CHECK-NEXT:    [[IDXPROM4736:%.*]] = zext i32 [[ADD41]] to i64
; CHECK-NEXT:    br label [[WHILE_BODY:%.*]]
; CHECK:       while.body:
; CHECK-NEXT:    [[IDXPROM4738:%.*]] = phi i64 [ [[IDXPROM47:%.*]], [[WHILE_BODY]] ], [ [[IDXPROM4736]], [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[POS_337:%.*]] = phi i32 [ [[INC46:%.*]], [[WHILE_BODY]] ], [ [[ADD41]], [[ENTRY]] ]
; CHECK-NEXT:    [[INC46]] = add i32 [[POS_337]], 1
; CHECK-NEXT:    [[ARRAYIDX48:%.*]] = getelementptr inbounds [1024 x i8], ptr undef, i64 0, i64 [[IDXPROM4738]]
; CHECK-NEXT:    store i8 0, ptr [[ARRAYIDX48]], align 1
; CHECK-NEXT:    [[AND43:%.*]] = and i32 [[INC46]], 3
; CHECK-NEXT:    [[CMP44:%.*]] = icmp eq i32 [[AND43]], 0
; CHECK-NEXT:    [[IDXPROM47]] = zext i32 [[INC46]] to i64
; CHECK-NEXT:    br i1 [[CMP44]], label [[WHILE_END:%.*]], label [[WHILE_BODY]]
; CHECK:       while.end:
; CHECK-NEXT:    [[INC46_LCSSA:%.*]] = phi i32 [ [[INC46]], [[WHILE_BODY]] ]
; CHECK-NEXT:    [[ADD58:%.*]] = add i32 [[INC46_LCSSA]], 4
; CHECK-NEXT:    ret void
;
entry:
  %add41 = add i32 undef, undef
  %idxprom4736 = zext i32 %add41 to i64
  br label %while.body

while.body:
  %idxprom4738 = phi i64 [ %idxprom47, %while.body ], [ %idxprom4736, %entry ]
  %pos.337 = phi i32 [ %inc46, %while.body ], [ %add41, %entry ]
  %inc46 = add i32 %pos.337, 1
  %arrayidx48 = getelementptr inbounds [1024 x i8], ptr undef, i64 0, i64 %idxprom4738
  store i8 0, ptr %arrayidx48, align 1
  %and43 = and i32 %inc46, 3
  %cmp44 = icmp eq i32 %and43, 0
  %idxprom47 = zext i32 %inc46 to i64
  br i1 %cmp44, label %while.end, label %while.body

while.end:
  %add58 = add i32 %inc46, 4
  ret void
}

; Make sure LV doesn't crash on IR where some LCSSA uses are unreachable.
define i32 @pr57508(ptr %src) {
; CHECK-LABEL: @pr57508(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 false, label [[SCALAR_PH:%.*]], label [[VECTOR_PH:%.*]]
; CHECK:       vector.ph:
; CHECK-NEXT:    br label [[VECTOR_BODY:%.*]]
; CHECK:       vector.body:
; CHECK-NEXT:    [[INDEX:%.*]] = phi i64 [ 0, [[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], [[VECTOR_BODY]] ]
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i64 [[INDEX]], 4
; CHECK-NEXT:    [[TMP0:%.*]] = icmp eq i64 [[INDEX_NEXT]], 2000
; CHECK-NEXT:    br i1 [[TMP0]], label [[MIDDLE_BLOCK:%.*]], label [[VECTOR_BODY]], !llvm.loop [[LOOP4:![0-9]+]]
; CHECK:       middle.block:
; CHECK-NEXT:    br label [[SCALAR_PH]]
; CHECK:       scalar.ph:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i64 [ 2000, [[MIDDLE_BLOCK]] ], [ 0, [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[BC_RESUME_VAL1:%.*]] = phi i32 [ 2000, [[MIDDLE_BLOCK]] ], [ 0, [[ENTRY]] ]
; CHECK-NEXT:    br label [[LOOP:%.*]]
; CHECK:       loop:
; CHECK-NEXT:    [[IV:%.*]] = phi i64 [ [[IV_NEXT:%.*]], [[LOOP]] ], [ [[BC_RESUME_VAL]], [[SCALAR_PH]] ]
; CHECK-NEXT:    [[LOCAL:%.*]] = phi i32 [ [[LOCAL_NEXT:%.*]], [[LOOP]] ], [ [[BC_RESUME_VAL1]], [[SCALAR_PH]] ]
; CHECK-NEXT:    [[IV_NEXT]] = add nuw nsw i64 [[IV]], 1
; CHECK-NEXT:    [[LOCAL_NEXT]] = add i32 [[LOCAL]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i64 [[IV]], 2000
; CHECK-NEXT:    br i1 [[EC]], label [[LOOP_EXIT:%.*]], label [[LOOP]], !llvm.loop [[LOOP5:![0-9]+]]
; CHECK:       loop.exit:
; CHECK-NEXT:    unreachable
; CHECK:       bb:
; CHECK-NEXT:    [[LOCAL_USE:%.*]] = add i32 poison, 1
; CHECK-NEXT:    ret i32 [[LOCAL_USE]]
;
entry:
  br label %loop

loop:
  %iv = phi i64 [ %iv.next, %loop ], [ 0, %entry ]
  %local = phi i32 [ %local.next, %loop ], [ 0, %entry ]
  %iv.next = add nuw nsw i64 %iv, 1
  %local.next  = add i32 %local, 1
  %ec = icmp eq i64 %iv, 2000
  br i1 %ec, label %loop.exit, label %loop

loop.exit:
  unreachable

bb:
  %local.use = add i32 %local, 1
  ret i32 %local.use
}

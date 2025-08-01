; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --version 5
; RUN: opt -passes=loop-vectorize -force-vector-width=2 -force-vector-interleave=2 -S %s | FileCheck %s
; RUN: opt -passes=loop-vectorize -force-vector-width=2 -force-vector-interleave=2 -prefer-inloop-reductions -S %s | FileCheck %s

define float @maximumnum_intrinsic(ptr readonly %x) {
; CHECK-LABEL: define float @maximumnum_intrinsic(
; CHECK-SAME: ptr readonly [[X:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    br i1 false, label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i32 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP3:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI1:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP4:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[GEP]], i32 2
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x float>, ptr [[GEP]], align 4
; CHECK-NEXT:    [[WIDE_LOAD2:%.*]] = load <2 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP3]] = call <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[VEC_PHI]], <2 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP4]] = call <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[VEC_PHI1]], <2 x float> [[WIDE_LOAD2]])
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i32 [[IV]], 4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i32 [[INDEX_NEXT]], 1024
; CHECK-NEXT:    br i1 [[TMP5]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP0:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[RDX_MINMAX:%.*]] = call <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[TMP3]], <2 x float> [[TMP4]])
; CHECK-NEXT:    [[TMP6:%.*]] = call float @llvm.vector.reduce.fmax.v2f32(<2 x float> [[RDX_MINMAX]])
; CHECK-NEXT:    br label %[[EXIT:.*]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i32 [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    [[BC_MERGE_RDX:%.*]] = phi float [ 0.000000e+00, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[INC:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[RED:%.*]] = phi float [ [[BC_MERGE_RDX]], %[[SCALAR_PH]] ], [ [[RED_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV1]]
; CHECK-NEXT:    [[L:%.*]] = load float, ptr [[GEP1]], align 4
; CHECK-NEXT:    [[RED_NEXT]] = tail call float @llvm.maximumnum.f32(float [[RED]], float [[L]])
; CHECK-NEXT:    [[INC]] = add nuw nsw i32 [[IV1]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i32 [[INC]], 1024
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP]], !llvm.loop [[LOOP3:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    [[RED_NEXT_LCSSA:%.*]] = phi float [ [[RED_NEXT]], %[[LOOP]] ], [ [[TMP6]], %[[MIDDLE_BLOCK]] ]
; CHECK-NEXT:    ret float [[RED_NEXT_LCSSA]]
;
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %red = phi float [ 0.000000e+00, %entry ], [ %red.next, %loop ]
  %gep = getelementptr inbounds float, ptr %x, i32 %iv
  %l = load float, ptr %gep, align 4
  %red.next = tail call float @llvm.maximumnum.f32(float %red, float %l)
  %inc = add nuw nsw i32 %iv, 1
  %ec = icmp eq i32 %inc, 1024
  br i1 %ec, label %exit, label %loop

exit:
  ret float %red.next
}

define float @maximumnum_intrinsic_fast(ptr readonly %x) {
; CHECK-LABEL: define float @maximumnum_intrinsic_fast(
; CHECK-SAME: ptr readonly [[X:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    br i1 false, label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i32 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP3:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI1:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP4:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[GEP]], i32 2
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x float>, ptr [[GEP]], align 4
; CHECK-NEXT:    [[WIDE_LOAD2:%.*]] = load <2 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP3]] = call fast <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[VEC_PHI]], <2 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP4]] = call fast <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[VEC_PHI1]], <2 x float> [[WIDE_LOAD2]])
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i32 [[IV]], 4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i32 [[INDEX_NEXT]], 1024
; CHECK-NEXT:    br i1 [[TMP5]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP4:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[RDX_MINMAX:%.*]] = call fast <2 x float> @llvm.maximumnum.v2f32(<2 x float> [[TMP3]], <2 x float> [[TMP4]])
; CHECK-NEXT:    [[TMP6:%.*]] = call fast float @llvm.vector.reduce.fmax.v2f32(<2 x float> [[RDX_MINMAX]])
; CHECK-NEXT:    br label %[[EXIT:.*]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i32 [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    [[BC_MERGE_RDX:%.*]] = phi float [ 0.000000e+00, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[INC:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[RED:%.*]] = phi float [ [[BC_MERGE_RDX]], %[[SCALAR_PH]] ], [ [[RED_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV1]]
; CHECK-NEXT:    [[L:%.*]] = load float, ptr [[GEP1]], align 4
; CHECK-NEXT:    [[RED_NEXT]] = tail call fast float @llvm.maximumnum.f32(float [[RED]], float [[L]])
; CHECK-NEXT:    [[INC]] = add nuw nsw i32 [[IV1]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i32 [[INC]], 1024
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP]], !llvm.loop [[LOOP5:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    [[RED_NEXT_LCSSA:%.*]] = phi float [ [[RED_NEXT]], %[[LOOP]] ], [ [[TMP6]], %[[MIDDLE_BLOCK]] ]
; CHECK-NEXT:    ret float [[RED_NEXT_LCSSA]]
;
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %red = phi float [ 0.000000e+00, %entry ], [ %red.next, %loop ]
  %gep = getelementptr inbounds float, ptr %x, i32 %iv
  %l = load float, ptr %gep, align 4
  %red.next = tail call fast float @llvm.maximumnum.f32(float %red, float %l)
  %inc = add nuw nsw i32 %iv, 1
  %ec = icmp eq i32 %inc, 1024
  br i1 %ec, label %exit, label %loop

exit:
  ret float %red.next
}

define float @minimumnum_intrinsic(ptr readonly %x) {
; CHECK-LABEL: define float @minimumnum_intrinsic(
; CHECK-SAME: ptr readonly [[X:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    br i1 false, label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i32 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP3:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI1:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP4:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[GEP]], i32 2
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x float>, ptr [[GEP]], align 4
; CHECK-NEXT:    [[WIDE_LOAD2:%.*]] = load <2 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP3]] = call <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[VEC_PHI]], <2 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP4]] = call <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[VEC_PHI1]], <2 x float> [[WIDE_LOAD2]])
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i32 [[IV]], 4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i32 [[INDEX_NEXT]], 1024
; CHECK-NEXT:    br i1 [[TMP5]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP6:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[RDX_MINMAX:%.*]] = call <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[TMP3]], <2 x float> [[TMP4]])
; CHECK-NEXT:    [[TMP6:%.*]] = call float @llvm.vector.reduce.fmin.v2f32(<2 x float> [[RDX_MINMAX]])
; CHECK-NEXT:    br label %[[EXIT:.*]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i32 [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    [[BC_MERGE_RDX:%.*]] = phi float [ 0.000000e+00, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[INC:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[RED:%.*]] = phi float [ [[BC_MERGE_RDX]], %[[SCALAR_PH]] ], [ [[RED_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV1]]
; CHECK-NEXT:    [[L:%.*]] = load float, ptr [[GEP1]], align 4
; CHECK-NEXT:    [[RED_NEXT]] = tail call float @llvm.minimumnum.f32(float [[RED]], float [[L]])
; CHECK-NEXT:    [[INC]] = add nuw nsw i32 [[IV1]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i32 [[INC]], 1024
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP]], !llvm.loop [[LOOP7:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    [[RED_NEXT_LCSSA:%.*]] = phi float [ [[RED_NEXT]], %[[LOOP]] ], [ [[TMP6]], %[[MIDDLE_BLOCK]] ]
; CHECK-NEXT:    ret float [[RED_NEXT_LCSSA]]
;
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %red = phi float [ 0.000000e+00, %entry ], [ %red.next, %loop ]
  %gep = getelementptr inbounds float, ptr %x, i32 %iv
  %l = load float, ptr %gep, align 4
  %red.next = tail call float @llvm.minimumnum.f32(float %red, float %l)
  %inc = add nuw nsw i32 %iv, 1
  %ec = icmp eq i32 %inc, 1024
  br i1 %ec, label %exit, label %loop

exit:
  ret float %red.next
}

define float @minimumnum_intrinsic_fast(ptr readonly %x) {
; CHECK-LABEL: define float @minimumnum_intrinsic_fast(
; CHECK-SAME: ptr readonly [[X:%.*]]) {
; CHECK-NEXT:  [[ENTRY:.*]]:
; CHECK-NEXT:    br i1 false, label %[[SCALAR_PH:.*]], label %[[VECTOR_PH:.*]]
; CHECK:       [[VECTOR_PH]]:
; CHECK-NEXT:    br label %[[VECTOR_BODY:.*]]
; CHECK:       [[VECTOR_BODY]]:
; CHECK-NEXT:    [[IV:%.*]] = phi i32 [ 0, %[[VECTOR_PH]] ], [ [[INDEX_NEXT:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP3:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[VEC_PHI1:%.*]] = phi <2 x float> [ zeroinitializer, %[[VECTOR_PH]] ], [ [[TMP4:%.*]], %[[VECTOR_BODY]] ]
; CHECK-NEXT:    [[GEP:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV]]
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr inbounds float, ptr [[GEP]], i32 2
; CHECK-NEXT:    [[WIDE_LOAD:%.*]] = load <2 x float>, ptr [[GEP]], align 4
; CHECK-NEXT:    [[WIDE_LOAD2:%.*]] = load <2 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP3]] = call fast <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[VEC_PHI]], <2 x float> [[WIDE_LOAD]])
; CHECK-NEXT:    [[TMP4]] = call fast <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[VEC_PHI1]], <2 x float> [[WIDE_LOAD2]])
; CHECK-NEXT:    [[INDEX_NEXT]] = add nuw i32 [[IV]], 4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp eq i32 [[INDEX_NEXT]], 1024
; CHECK-NEXT:    br i1 [[TMP5]], label %[[MIDDLE_BLOCK:.*]], label %[[VECTOR_BODY]], !llvm.loop [[LOOP8:![0-9]+]]
; CHECK:       [[MIDDLE_BLOCK]]:
; CHECK-NEXT:    [[RDX_MINMAX:%.*]] = call fast <2 x float> @llvm.minimumnum.v2f32(<2 x float> [[TMP3]], <2 x float> [[TMP4]])
; CHECK-NEXT:    [[TMP6:%.*]] = call fast float @llvm.vector.reduce.fmin.v2f32(<2 x float> [[RDX_MINMAX]])
; CHECK-NEXT:    br label %[[EXIT:.*]]
; CHECK:       [[SCALAR_PH]]:
; CHECK-NEXT:    [[BC_RESUME_VAL:%.*]] = phi i32 [ 0, %[[ENTRY]] ]
; CHECK-NEXT:    [[BC_MERGE_RDX:%.*]] = phi float [ 0.000000e+00, %[[ENTRY]] ]
; CHECK-NEXT:    br label %[[LOOP:.*]]
; CHECK:       [[LOOP]]:
; CHECK-NEXT:    [[IV1:%.*]] = phi i32 [ [[BC_RESUME_VAL]], %[[SCALAR_PH]] ], [ [[INC:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[RED:%.*]] = phi float [ [[BC_MERGE_RDX]], %[[SCALAR_PH]] ], [ [[RED_NEXT:%.*]], %[[LOOP]] ]
; CHECK-NEXT:    [[GEP1:%.*]] = getelementptr inbounds float, ptr [[X]], i32 [[IV1]]
; CHECK-NEXT:    [[L:%.*]] = load float, ptr [[GEP1]], align 4
; CHECK-NEXT:    [[RED_NEXT]] = tail call fast float @llvm.minimumnum.f32(float [[RED]], float [[L]])
; CHECK-NEXT:    [[INC]] = add nuw nsw i32 [[IV1]], 1
; CHECK-NEXT:    [[EC:%.*]] = icmp eq i32 [[INC]], 1024
; CHECK-NEXT:    br i1 [[EC]], label %[[EXIT]], label %[[LOOP]], !llvm.loop [[LOOP9:![0-9]+]]
; CHECK:       [[EXIT]]:
; CHECK-NEXT:    [[RED_NEXT_LCSSA:%.*]] = phi float [ [[RED_NEXT]], %[[LOOP]] ], [ [[TMP6]], %[[MIDDLE_BLOCK]] ]
; CHECK-NEXT:    ret float [[RED_NEXT_LCSSA]]
;
entry:
  br label %loop

loop:
  %iv = phi i32 [ 0, %entry ], [ %inc, %loop ]
  %red = phi float [ 0.000000e+00, %entry ], [ %red.next, %loop ]
  %gep = getelementptr inbounds float, ptr %x, i32 %iv
  %l = load float, ptr %gep, align 4
  %red.next = tail call fast float @llvm.minimumnum.f32(float %red, float %l)
  %inc = add nuw nsw i32 %iv, 1
  %ec = icmp eq i32 %inc, 1024
  br i1 %ec, label %exit, label %loop

exit:
  ret float %red.next
}

declare float @llvm.minimumnum.f32(float, float)
declare float @llvm.maximumnum.f32(float, float)
;.
; CHECK: [[LOOP0]] = distinct !{[[LOOP0]], [[META1:![0-9]+]], [[META2:![0-9]+]]}
; CHECK: [[META1]] = !{!"llvm.loop.isvectorized", i32 1}
; CHECK: [[META2]] = !{!"llvm.loop.unroll.runtime.disable"}
; CHECK: [[LOOP3]] = distinct !{[[LOOP3]], [[META2]], [[META1]]}
; CHECK: [[LOOP4]] = distinct !{[[LOOP4]], [[META1]], [[META2]]}
; CHECK: [[LOOP5]] = distinct !{[[LOOP5]], [[META2]], [[META1]]}
; CHECK: [[LOOP6]] = distinct !{[[LOOP6]], [[META1]], [[META2]]}
; CHECK: [[LOOP7]] = distinct !{[[LOOP7]], [[META2]], [[META1]]}
; CHECK: [[LOOP8]] = distinct !{[[LOOP8]], [[META1]], [[META2]]}
; CHECK: [[LOOP9]] = distinct !{[[LOOP9]], [[META2]], [[META1]]}
;.

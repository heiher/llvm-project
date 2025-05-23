; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --version 5
; RUN: opt < %s -msan-check-access-address=0 -S -passes=msan                       2>&1 | FileCheck %s
; RUN: opt < %s -msan-check-access-address=0 -S -passes=msan -msan-track-origins=1 2>&1 | FileCheck -check-prefixes=ORIGINS %s

; REQUIRES: x86-registered-target

target datalayout = "e-p:64:64:64-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:64:64-f32:32:32-f64:64:64-v64:64:64-v128:128:128-a0:0:64-s0:64:64-f80:128:128-n8:16:32:64-S128"
target triple = "i386-unknown-linux-gnu"

; Store intrinsic.

define void @StoreIntrinsic(ptr %p, <4 x float> %x) nounwind uwtable sanitize_memory {
; CHECK-LABEL: define void @StoreIntrinsic(
; CHECK-SAME: ptr [[P:%.*]], <4 x float> [[X:%.*]]) #[[ATTR0:[0-9]+]] {
; CHECK-NEXT:    [[TMP5:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x i32>, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_tls to i64), i64 8) to ptr), align 8
; CHECK-NEXT:    call void @llvm.donothing()
; CHECK-NEXT:    [[TMP2:%.*]] = ptrtoint ptr [[P]] to i64
; CHECK-NEXT:    [[TMP3:%.*]] = and i64 [[TMP2]], -2147483649
; CHECK-NEXT:    [[TMP4:%.*]] = inttoptr i64 [[TMP3]] to ptr
; CHECK-NEXT:    store <4 x i32> [[TMP1]], ptr [[TMP4]], align 1
; CHECK-NEXT:    store <4 x float> [[X]], ptr [[P]], align 1
; CHECK-NEXT:    ret void
;
; ORIGINS-LABEL: define void @StoreIntrinsic(
; ORIGINS-SAME: ptr [[P:%.*]], <4 x float> [[X:%.*]]) #[[ATTR0:[0-9]+]] {
; ORIGINS-NEXT:    [[TMP10:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; ORIGINS-NEXT:    [[TMP1:%.*]] = load <4 x i32>, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_tls to i64), i64 8) to ptr), align 8
; ORIGINS-NEXT:    [[TMP2:%.*]] = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_origin_tls to i64), i64 8) to ptr), align 4
; ORIGINS-NEXT:    call void @llvm.donothing()
; ORIGINS-NEXT:    [[TMP3:%.*]] = ptrtoint ptr [[P]] to i64
; ORIGINS-NEXT:    [[TMP4:%.*]] = and i64 [[TMP3]], -2147483649
; ORIGINS-NEXT:    [[TMP5:%.*]] = inttoptr i64 [[TMP4]] to ptr
; ORIGINS-NEXT:    [[TMP6:%.*]] = add i64 [[TMP4]], 1073741824
; ORIGINS-NEXT:    [[TMP7:%.*]] = and i64 [[TMP6]], -4
; ORIGINS-NEXT:    [[TMP8:%.*]] = inttoptr i64 [[TMP7]] to ptr
; ORIGINS-NEXT:    store <4 x i32> [[TMP1]], ptr [[TMP5]], align 1
; ORIGINS-NEXT:    [[TMP9:%.*]] = bitcast <4 x i32> [[TMP1]] to i128
; ORIGINS-NEXT:    [[_MSCMP:%.*]] = icmp ne i128 [[TMP9]], 0
; ORIGINS-NEXT:    br i1 [[_MSCMP]], label %[[BB11:.*]], label %[[BB15:.*]], !prof [[PROF1:![0-9]+]]
; ORIGINS:       [[BB11]]:
; ORIGINS-NEXT:    store i32 [[TMP2]], ptr [[TMP8]], align 4
; ORIGINS-NEXT:    [[TMP11:%.*]] = getelementptr i32, ptr [[TMP8]], i32 1
; ORIGINS-NEXT:    store i32 [[TMP2]], ptr [[TMP11]], align 4
; ORIGINS-NEXT:    [[TMP12:%.*]] = getelementptr i32, ptr [[TMP8]], i32 2
; ORIGINS-NEXT:    store i32 [[TMP2]], ptr [[TMP12]], align 4
; ORIGINS-NEXT:    [[TMP13:%.*]] = getelementptr i32, ptr [[TMP8]], i32 3
; ORIGINS-NEXT:    store i32 [[TMP2]], ptr [[TMP13]], align 4
; ORIGINS-NEXT:    br label %[[BB15]]
; ORIGINS:       [[BB15]]:
; ORIGINS-NEXT:    store <4 x float> [[X]], ptr [[P]], align 1
; ORIGINS-NEXT:    ret void
;
  call void @llvm.x86.sse.storeu.ps(ptr %p, <4 x float> %x)
  ret void
}

declare void @llvm.x86.sse.storeu.ps(ptr, <4 x float>) nounwind



; Load intrinsic.

define <16 x i8> @LoadIntrinsic(ptr %p) nounwind uwtable sanitize_memory {
; CHECK-LABEL: define <16 x i8> @LoadIntrinsic(
; CHECK-SAME: ptr [[P:%.*]]) #[[ATTR0]] {
; CHECK-NEXT:    [[TMP4:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; CHECK-NEXT:    call void @llvm.donothing()
; CHECK-NEXT:    [[TMP1:%.*]] = ptrtoint ptr [[P]] to i64
; CHECK-NEXT:    [[TMP2:%.*]] = and i64 [[TMP1]], -2147483649
; CHECK-NEXT:    [[TMP3:%.*]] = inttoptr i64 [[TMP2]] to ptr
; CHECK-NEXT:    [[_MSLD:%.*]] = load <16 x i8>, ptr [[TMP3]], align 1
; CHECK-NEXT:    [[CALL:%.*]] = call <16 x i8> @llvm.x86.sse3.ldu.dq(ptr [[P]])
; CHECK-NEXT:    store <16 x i8> [[_MSLD]], ptr @__msan_retval_tls, align 8
; CHECK-NEXT:    ret <16 x i8> [[CALL]]
;
; ORIGINS-LABEL: define <16 x i8> @LoadIntrinsic(
; ORIGINS-SAME: ptr [[P:%.*]]) #[[ATTR0]] {
; ORIGINS-NEXT:    [[TMP8:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; ORIGINS-NEXT:    call void @llvm.donothing()
; ORIGINS-NEXT:    [[TMP1:%.*]] = ptrtoint ptr [[P]] to i64
; ORIGINS-NEXT:    [[TMP2:%.*]] = and i64 [[TMP1]], -2147483649
; ORIGINS-NEXT:    [[TMP3:%.*]] = inttoptr i64 [[TMP2]] to ptr
; ORIGINS-NEXT:    [[TMP4:%.*]] = add i64 [[TMP2]], 1073741824
; ORIGINS-NEXT:    [[TMP5:%.*]] = and i64 [[TMP4]], -4
; ORIGINS-NEXT:    [[TMP6:%.*]] = inttoptr i64 [[TMP5]] to ptr
; ORIGINS-NEXT:    [[_MSLD:%.*]] = load <16 x i8>, ptr [[TMP3]], align 1
; ORIGINS-NEXT:    [[TMP7:%.*]] = load i32, ptr [[TMP6]], align 4
; ORIGINS-NEXT:    [[CALL:%.*]] = call <16 x i8> @llvm.x86.sse3.ldu.dq(ptr [[P]])
; ORIGINS-NEXT:    store <16 x i8> [[_MSLD]], ptr @__msan_retval_tls, align 8
; ORIGINS-NEXT:    store i32 [[TMP7]], ptr @__msan_retval_origin_tls, align 4
; ORIGINS-NEXT:    ret <16 x i8> [[CALL]]
;
  %call = call <16 x i8> @llvm.x86.sse3.ldu.dq(ptr %p)
  ret <16 x i8> %call
}

declare <16 x i8> @llvm.x86.sse3.ldu.dq(ptr %p) nounwind



; Simple NoMem intrinsic
; Check that shadow is OR'ed, and origin is Select'ed
; And no shadow checks!

define <8 x i16> @Pmulhuw128(<8 x i16> %a, <8 x i16> %b) nounwind uwtable sanitize_memory {
; CHECK-LABEL: define <8 x i16> @Pmulhuw128(
; CHECK-SAME: <8 x i16> [[A:%.*]], <8 x i16> [[B:%.*]]) #[[ATTR0]] {
; CHECK-NEXT:    [[TMP1:%.*]] = load <8 x i16>, ptr @__msan_param_tls, align 8
; CHECK-NEXT:    [[TMP2:%.*]] = load <8 x i16>, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_tls to i64), i64 16) to ptr), align 8
; CHECK-NEXT:    [[TMP3:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; CHECK-NEXT:    call void @llvm.donothing()
; CHECK-NEXT:    [[_MSPROP:%.*]] = or <8 x i16> [[TMP1]], [[TMP2]]
; CHECK-NEXT:    [[CALL:%.*]] = call <8 x i16> @llvm.x86.sse2.pmulhu.w(<8 x i16> [[A]], <8 x i16> [[B]])
; CHECK-NEXT:    store <8 x i16> [[_MSPROP]], ptr @__msan_retval_tls, align 8
; CHECK-NEXT:    ret <8 x i16> [[CALL]]
;
; ORIGINS-LABEL: define <8 x i16> @Pmulhuw128(
; ORIGINS-SAME: <8 x i16> [[A:%.*]], <8 x i16> [[B:%.*]]) #[[ATTR0]] {
; ORIGINS-NEXT:    [[TMP1:%.*]] = load <8 x i16>, ptr @__msan_param_tls, align 8
; ORIGINS-NEXT:    [[TMP2:%.*]] = load i32, ptr @__msan_param_origin_tls, align 4
; ORIGINS-NEXT:    [[TMP3:%.*]] = load <8 x i16>, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_tls to i64), i64 16) to ptr), align 8
; ORIGINS-NEXT:    [[TMP4:%.*]] = load i32, ptr inttoptr (i64 add (i64 ptrtoint (ptr @__msan_param_origin_tls to i64), i64 16) to ptr), align 4
; ORIGINS-NEXT:    [[TMP8:%.*]] = load i64, ptr @__msan_va_arg_overflow_size_tls, align 8
; ORIGINS-NEXT:    call void @llvm.donothing()
; ORIGINS-NEXT:    [[_MSPROP:%.*]] = or <8 x i16> [[TMP1]], [[TMP3]]
; ORIGINS-NEXT:    [[TMP5:%.*]] = bitcast <8 x i16> [[TMP3]] to i128
; ORIGINS-NEXT:    [[TMP6:%.*]] = icmp ne i128 [[TMP5]], 0
; ORIGINS-NEXT:    [[TMP7:%.*]] = select i1 [[TMP6]], i32 [[TMP4]], i32 [[TMP2]]
; ORIGINS-NEXT:    [[CALL:%.*]] = call <8 x i16> @llvm.x86.sse2.pmulhu.w(<8 x i16> [[A]], <8 x i16> [[B]])
; ORIGINS-NEXT:    store <8 x i16> [[_MSPROP]], ptr @__msan_retval_tls, align 8
; ORIGINS-NEXT:    store i32 [[TMP7]], ptr @__msan_retval_origin_tls, align 4
; ORIGINS-NEXT:    ret <8 x i16> [[CALL]]
;
  %call = call <8 x i16> @llvm.x86.sse2.pmulhu.w(<8 x i16> %a, <8 x i16> %b)
  ret <8 x i16> %call
}

declare <8 x i16> @llvm.x86.sse2.pmulhu.w(<8 x i16> %a, <8 x i16> %b) nounwind
;.
; ORIGINS: [[PROF1]] = !{!"branch_weights", i32 1, i32 1048575}
;.

; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt -passes=slp-vectorizer -S -slp-revec -slp-max-reg-size=1024 -slp-threshold=-100 %s | FileCheck %s

define void @test1(ptr %a, ptr %b, ptr %c) {
; CHECK-LABEL: @test1(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load <16 x i32>, ptr [[A:%.*]], align 4
; CHECK-NEXT:    [[TMP1:%.*]] = load <16 x i32>, ptr [[B:%.*]], align 4
; CHECK-NEXT:    [[TMP2:%.*]] = add <16 x i32> [[TMP1]], [[TMP0]]
; CHECK-NEXT:    store <16 x i32> [[TMP2]], ptr [[C:%.*]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %arrayidx3 = getelementptr inbounds i32, ptr %a, i64 4
  %arrayidx7 = getelementptr inbounds i32, ptr %a, i64 8
  %arrayidx11 = getelementptr inbounds i32, ptr %a, i64 12
  %0 = load <4 x i32>, ptr %a, align 4
  %1 = load <4 x i32>, ptr %arrayidx3, align 4
  %2 = load <4 x i32>, ptr %arrayidx7, align 4
  %3 = load <4 x i32>, ptr %arrayidx11, align 4
  %arrayidx19 = getelementptr inbounds i32, ptr %b, i64 4
  %arrayidx23 = getelementptr inbounds i32, ptr %b, i64 8
  %arrayidx27 = getelementptr inbounds i32, ptr %b, i64 12
  %4 = load <4 x i32>, ptr %b, align 4
  %5 = load <4 x i32>, ptr %arrayidx19, align 4
  %6 = load <4 x i32>, ptr %arrayidx23, align 4
  %7 = load <4 x i32>, ptr %arrayidx27, align 4
  %add.i = add <4 x i32> %4, %0
  %add.i63 = add <4 x i32> %5, %1
  %add.i64 = add <4 x i32> %6, %2
  %add.i65 = add <4 x i32> %7, %3
  %arrayidx36 = getelementptr inbounds i32, ptr %c, i64 4
  %arrayidx39 = getelementptr inbounds i32, ptr %c, i64 8
  %arrayidx42 = getelementptr inbounds i32, ptr %c, i64 12
  store <4 x i32> %add.i, ptr %c, align 4
  store <4 x i32> %add.i63, ptr %arrayidx36, align 4
  store <4 x i32> %add.i64, ptr %arrayidx39, align 4
  store <4 x i32> %add.i65, ptr %arrayidx42, align 4
  ret void
}

define void @test2(ptr %in, ptr %out) {
; CHECK-LABEL: @test2(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load <16 x i16>, ptr [[IN:%.*]], align 2
; CHECK-NEXT:    [[TMP1:%.*]] = call <16 x i16> @llvm.sadd.sat.v16i16(<16 x i16> [[TMP0]], <16 x i16> [[TMP0]])
; CHECK-NEXT:    store <16 x i16> [[TMP1]], ptr [[OUT:%.*]], align 2
; CHECK-NEXT:    ret void
;
entry:
  %0 = getelementptr i16, ptr %in, i64 8
  %1 = load <8 x i16>, ptr %in, align 2
  %2 = load <8 x i16>, ptr %0, align 2
  %3 = call <8 x i16> @llvm.sadd.sat.v8i16(<8 x i16> %1, <8 x i16> %1)
  %4 = call <8 x i16> @llvm.sadd.sat.v8i16(<8 x i16> %2, <8 x i16> %2)
  %5 = getelementptr i16, ptr %out, i64 8
  store <8 x i16> %3, ptr %out, align 2
  store <8 x i16> %4, ptr %5, align 2
  ret void
}

define void @test3(ptr %x, ptr %y, ptr %z) {
; CHECK-LABEL: @test3(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = insertelement <2 x ptr> poison, ptr [[X:%.*]], i32 0
; CHECK-NEXT:    [[TMP1:%.*]] = insertelement <2 x ptr> [[TMP0]], ptr [[Y:%.*]], i32 1
; CHECK-NEXT:    [[TMP2:%.*]] = icmp eq <2 x ptr> [[TMP1]], zeroinitializer
; CHECK-NEXT:    [[TMP3:%.*]] = load <8 x i32>, ptr [[X]], align 4
; CHECK-NEXT:    [[TMP4:%.*]] = load <8 x i32>, ptr [[Y]], align 4
; CHECK-NEXT:    [[TMP5:%.*]] = shufflevector <2 x i1> [[TMP2]], <2 x i1> poison, <8 x i32> <i32 0, i32 0, i32 0, i32 0, i32 1, i32 1, i32 1, i32 1>
; CHECK-NEXT:    [[TMP6:%.*]] = select <8 x i1> [[TMP5]], <8 x i32> [[TMP3]], <8 x i32> [[TMP4]]
; CHECK-NEXT:    store <8 x i32> [[TMP6]], ptr [[Z:%.*]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %0 = getelementptr inbounds i32, ptr %x, i64 4
  %1 = getelementptr inbounds i32, ptr %y, i64 4
  %2 = load <4 x i32>, ptr %x, align 4
  %3 = load <4 x i32>, ptr %0, align 4
  %4 = load <4 x i32>, ptr %y, align 4
  %5 = load <4 x i32>, ptr %1, align 4
  %6 = icmp eq ptr %x, null
  %7 = icmp eq ptr %y, null
  %8 = select i1 %6, <4 x i32> %2, <4 x i32> %4
  %9 = select i1 %7, <4 x i32> %3, <4 x i32> %5
  %10 = getelementptr inbounds i32, ptr %z, i64 4
  store <4 x i32> %8, ptr %z, align 4
  store <4 x i32> %9, ptr %10, align 4
  ret void
}

define void @test4(ptr %in, ptr %out) {
; CHECK-LABEL: @test4(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load <8 x float>, ptr [[IN:%.*]], align 4
; CHECK-NEXT:    [[TMP1:%.*]] = shufflevector <8 x float> [[TMP0]], <8 x float> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    [[TMP6:%.*]] = fmul <16 x float> [[TMP1]], zeroinitializer
; CHECK-NEXT:    [[TMP9:%.*]] = shufflevector <16 x float> [[TMP1]], <16 x float> <float undef, float undef, float undef, float undef, float undef, float undef, float undef, float undef, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 24, i32 25, i32 26, i32 27, i32 28, i32 29, i32 30, i32 31>
; CHECK-NEXT:    [[TMP10:%.*]] = fadd <16 x float> [[TMP9]], [[TMP6]]
; CHECK-NEXT:    [[TMP5:%.*]] = fcmp ogt <16 x float> [[TMP10]], zeroinitializer
; CHECK-NEXT:    [[TMP12:%.*]] = getelementptr i1, ptr [[OUT:%.*]], i64 8
; CHECK-NEXT:    [[TMP13:%.*]] = shufflevector <16 x i1> [[TMP5]], <16 x i1> poison, <8 x i32> <i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    store <8 x i1> [[TMP13]], ptr [[OUT]], align 1
; CHECK-NEXT:    [[TMP14:%.*]] = shufflevector <16 x i1> [[TMP5]], <16 x i1> poison, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    store <8 x i1> [[TMP14]], ptr [[TMP12]], align 1
; CHECK-NEXT:    ret void
;
entry:
  %0 = load <8 x float>, ptr %in, align 4
  %1 = fmul <8 x float> %0, zeroinitializer
  %2 = fmul <8 x float> %0, zeroinitializer
  %3 = fadd <8 x float> zeroinitializer, %1
  %4 = fadd <8 x float> %0, %2
  %5 = fcmp ogt <8 x float> %3, zeroinitializer
  %6 = fcmp ogt <8 x float> %4, zeroinitializer
  %7 = getelementptr i1, ptr %out, i64 8
  store <8 x i1> %5, ptr %out, align 1
  store <8 x i1> %6, ptr %7, align 1
  ret void
}

define void @test5(ptr %ptr0, ptr %ptr1) {
; CHECK-LABEL: @test5(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[GETELEMENTPTR0:%.*]] = getelementptr i8, ptr null, i64 0
; CHECK-NEXT:    [[TMP0:%.*]] = insertelement <4 x ptr> <ptr null, ptr null, ptr undef, ptr undef>, ptr [[GETELEMENTPTR0]], i32 2
; CHECK-NEXT:    [[TMP1:%.*]] = insertelement <4 x ptr> [[TMP0]], ptr null, i32 3
; CHECK-NEXT:    [[TMP2:%.*]] = icmp ult <4 x ptr> zeroinitializer, [[TMP1]]
; CHECK-NEXT:    [[TMP3:%.*]] = insertelement <4 x ptr> <ptr poison, ptr null, ptr null, ptr null>, ptr [[PTR0:%.*]], i32 0
; CHECK-NEXT:    [[TMP4:%.*]] = insertelement <4 x ptr> [[TMP1]], ptr [[PTR1:%.*]], i32 3
; CHECK-NEXT:    [[TMP5:%.*]] = icmp ult <4 x ptr> [[TMP3]], [[TMP4]]
; CHECK-NEXT:    ret void
;
entry:
  %getelementptr0 = getelementptr i8, ptr null, i64 0
  %0 = insertelement <4 x ptr> <ptr null, ptr null, ptr undef, ptr undef>, ptr %getelementptr0, i32 2
  %1 = insertelement <4 x ptr> %0, ptr null, i32 3
  %2 = icmp ult <4 x ptr> zeroinitializer, %1
  %3 = insertelement <4 x ptr> <ptr poison, ptr null, ptr null, ptr null>, ptr %ptr0, i32 0
  %4 = insertelement <4 x ptr> %1, ptr %ptr1, i32 3
  %5 = icmp ult <4 x ptr> %3, %4
  ret void
}

define <4 x i1> @test6(ptr %in1, ptr %in2) {
; CHECK-LABEL: @test6(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load <4 x i32>, ptr [[IN1:%.*]], align 4
; CHECK-NEXT:    [[TMP1:%.*]] = load <4 x i16>, ptr [[IN2:%.*]], align 2
; CHECK-NEXT:    [[TMP2:%.*]] = shufflevector <4 x i32> [[TMP0]], <4 x i32> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3>
; CHECK-NEXT:    [[TMP3:%.*]] = shufflevector <4 x i16> [[TMP1]], <4 x i16> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3>
; CHECK-NEXT:    [[TMP21:%.*]] = icmp eq <16 x i16> [[TMP3]], zeroinitializer
; CHECK-NEXT:    [[TMP5:%.*]] = shufflevector <16 x i32> [[TMP2]], <16 x i32> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP6:%.*]] = icmp ugt <32 x i32> [[TMP5]], zeroinitializer
; CHECK-NEXT:    [[TMP11:%.*]] = shufflevector <32 x i1> [[TMP6]], <32 x i1> poison, <16 x i32> <i32 16, i32 17, i32 18, i32 19, i32 20, i32 21, i32 22, i32 23, i32 24, i32 25, i32 26, i32 27, i32 28, i32 29, i32 30, i32 31>
; CHECK-NEXT:    [[TMP22:%.*]] = and <16 x i1> [[TMP11]], [[TMP21]]
; CHECK-NEXT:    [[TMP23:%.*]] = shufflevector <32 x i1> [[TMP6]], <32 x i1> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP24:%.*]] = and <16 x i1> [[TMP22]], [[TMP23]]
; CHECK-NEXT:    [[TMP25:%.*]] = shufflevector <16 x i1> [[TMP24]], <16 x i1> poison, <4 x i32> <i32 0, i32 4, i32 8, i32 12>
; CHECK-NEXT:    [[TMP26:%.*]] = call i1 @llvm.vector.reduce.or.v4i1(<4 x i1> [[TMP25]])
; CHECK-NEXT:    [[TMP27:%.*]] = insertelement <4 x i1> poison, i1 [[TMP26]], i64 0
; CHECK-NEXT:    [[TMP28:%.*]] = shufflevector <16 x i1> [[TMP24]], <16 x i1> poison, <4 x i32> <i32 1, i32 5, i32 9, i32 13>
; CHECK-NEXT:    [[TMP29:%.*]] = call i1 @llvm.vector.reduce.or.v4i1(<4 x i1> [[TMP28]])
; CHECK-NEXT:    [[TMP30:%.*]] = insertelement <4 x i1> [[TMP27]], i1 [[TMP29]], i64 1
; CHECK-NEXT:    [[TMP31:%.*]] = shufflevector <16 x i1> [[TMP24]], <16 x i1> poison, <4 x i32> <i32 2, i32 6, i32 10, i32 14>
; CHECK-NEXT:    [[TMP32:%.*]] = call i1 @llvm.vector.reduce.or.v4i1(<4 x i1> [[TMP31]])
; CHECK-NEXT:    [[TMP33:%.*]] = insertelement <4 x i1> [[TMP30]], i1 [[TMP32]], i64 2
; CHECK-NEXT:    [[TMP34:%.*]] = shufflevector <16 x i1> [[TMP24]], <16 x i1> poison, <4 x i32> <i32 3, i32 7, i32 11, i32 15>
; CHECK-NEXT:    [[TMP35:%.*]] = call i1 @llvm.vector.reduce.or.v4i1(<4 x i1> [[TMP34]])
; CHECK-NEXT:    [[TMP36:%.*]] = insertelement <4 x i1> [[TMP33]], i1 [[TMP35]], i64 3
; CHECK-NEXT:    [[VBSL:%.*]] = select <4 x i1> [[TMP36]], <4 x i32> <i32 1, i32 2, i32 3, i32 4>, <4 x i32> <i32 5, i32 6, i32 7, i32 8>
; CHECK-NEXT:    [[CMP:%.*]] = icmp ugt <4 x i32> [[VBSL]], <i32 2, i32 3, i32 4, i32 5>
; CHECK-NEXT:    ret <4 x i1> [[CMP]]
;
entry:
  %0 = load <4 x i32>, ptr %in1, align 4
  %1 = load <4 x i16>, ptr %in2, align 2
  %cmp000 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp001 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp002 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp003 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp100 = icmp eq <4 x i16> %1, zeroinitializer
  %cmp101 = icmp eq <4 x i16> %1, zeroinitializer
  %cmp102 = icmp eq <4 x i16> %1, zeroinitializer
  %cmp103 = icmp eq <4 x i16> %1, zeroinitializer
  %and.cmp0 = and <4 x i1> %cmp000, %cmp100
  %and.cmp1 = and <4 x i1> %cmp001, %cmp101
  %and.cmp2 = and <4 x i1> %cmp002, %cmp102
  %and.cmp3 = and <4 x i1> %cmp003, %cmp103
  %cmp004 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp005 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp006 = icmp ugt <4 x i32> %0, zeroinitializer
  %cmp007 = icmp ugt <4 x i32> %0, zeroinitializer
  %and.cmp4 = and <4 x i1> %and.cmp0, %cmp004
  %and.cmp5 = and <4 x i1> %and.cmp1, %cmp005
  %and.cmp6 = and <4 x i1> %and.cmp2, %cmp006
  %and.cmp7 = and <4 x i1> %and.cmp3, %cmp007
  %or0 = or <4 x i1> %and.cmp5, %and.cmp4
  %or1 = or <4 x i1> %or0, %and.cmp6
  %or2 = or <4 x i1> %or1, %and.cmp7
  %vbsl = select <4 x i1> %or2, <4 x i32> <i32 1, i32 2, i32 3, i32 4>, <4 x i32> <i32 5, i32 6, i32 7, i32 8>
  %cmp = icmp ugt <4 x i32> %vbsl, <i32 2, i32 3, i32 4, i32 5>
  ret <4 x i1> %cmp
}

define void @test7() {
; CHECK-LABEL: @test7(
; CHECK-NEXT:    store <16 x i16> zeroinitializer, ptr null, align 2
; CHECK-NEXT:    ret void
;
  %1 = getelementptr i8, ptr null, i64 16
  %2 = trunc <8 x i64> zeroinitializer to <8 x i16>
  store <8 x i16> %2, ptr %1, align 2
  %3 = trunc <8 x i64> zeroinitializer to <8 x i16>
  store <8 x i16> %3, ptr null, align 2
  ret void
}

define void @test8() {
; CHECK-LABEL: @test8(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br i1 false, label [[FOR0:%.*]], label [[FOR_BODY:%.*]]
; CHECK:       for0:
; CHECK-NEXT:    [[TMP0:%.*]] = phi <8 x float> [ zeroinitializer, [[ENTRY:%.*]] ], [ [[TMP8:%.*]], [[FOR_BODY]] ]
; CHECK-NEXT:    ret void
; CHECK:       for.body:
; CHECK-NEXT:    [[TMP7:%.*]] = phi <4 x float> [ [[TMP7]], [[FOR_BODY]] ], [ zeroinitializer, [[ENTRY]] ]
; CHECK-NEXT:    [[TMP8]] = shufflevector <4 x float> [[TMP7]], <4 x float> poison, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 0, i32 1, i32 2, i32 3>
; CHECK-NEXT:    br i1 false, label [[FOR0]], label [[FOR_BODY]]
;
entry:
  br i1 false, label %for0, label %for.body

for0:
  %0 = phi <2 x float> [ zeroinitializer, %entry ], [ %4, %for.body ]
  %1 = phi <2 x float> [ zeroinitializer, %entry ], [ %5, %for.body ]
  %2 = phi <2 x float> [ zeroinitializer, %entry ], [ %4, %for.body ]
  %3 = phi <2 x float> [ zeroinitializer, %entry ], [ %5, %for.body ]
  ret void

for.body:
  %4 = phi <2 x float> [ %4, %for.body ], [ zeroinitializer, %entry ]
  %5 = phi <2 x float> [ %5, %for.body ], [ zeroinitializer, %entry ]
  br i1 false, label %for0, label %for.body
}

define void @test9() {
; CHECK-LABEL: @test9(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    br label [[FOR_BODY13:%.*]]
; CHECK:       for.body13:
; CHECK-NEXT:    store <8 x i32> zeroinitializer, ptr null, align 4
; CHECK-NEXT:    br label [[FOR_BODY13]]
;
entry:
  br label %for.body13

for.body13:                                       ; preds = %for.body13, %entry
  %vmovl.i111 = sext <4 x i16> zeroinitializer to <4 x i32>
  %vmovl.i110 = sext <4 x i16> zeroinitializer to <4 x i32>
  store <4 x i32> %vmovl.i111, ptr null, align 4
  %add.ptr29 = getelementptr i8, ptr null, i64 16
  store <4 x i32> %vmovl.i110, ptr %add.ptr29, align 4
  br label %for.body13
}

define void @test10() {
; CHECK-LABEL: @test10(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = load <16 x i8>, ptr null, align 1
; CHECK-NEXT:    [[TMP1:%.*]] = shufflevector <16 x i8> [[TMP0]], <16 x i8> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP4:%.*]] = shufflevector <16 x i8> [[TMP0]], <16 x i8> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP5:%.*]] = sext <16 x i8> [[TMP4]] to <16 x i16>
; CHECK-NEXT:    [[TMP6:%.*]] = shufflevector <16 x i16> [[TMP5]], <16 x i16> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP7:%.*]] = shufflevector <16 x i16> [[TMP5]], <16 x i16> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP8:%.*]] = trunc <16 x i16> [[TMP7]] to <16 x i8>
; CHECK-NEXT:    [[TMP9:%.*]] = sext <16 x i8> [[TMP8]] to <16 x i32>
; CHECK-NEXT:    store <16 x i32> [[TMP9]], ptr null, align 4
; CHECK-NEXT:    ret void
;
entry:
  %0 = load <16 x i8>, ptr null, align 1
  %shuffle.i = shufflevector <16 x i8> %0, <16 x i8> zeroinitializer, <8 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
  %shuffle.i107 = shufflevector <16 x i8> %0, <16 x i8> zeroinitializer, <8 x i32> <i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
  %vmovl.i106 = sext <8 x i8> %shuffle.i to <8 x i16>
  %vmovl.i = sext <8 x i8> %shuffle.i107 to <8 x i16>
  %shuffle.i113 = shufflevector <8 x i16> %vmovl.i106, <8 x i16> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %shuffle.i115 = shufflevector <8 x i16> %vmovl.i106, <8 x i16> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  %shuffle.i112 = shufflevector <8 x i16> %vmovl.i, <8 x i16> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %shuffle.i114 = shufflevector <8 x i16> %vmovl.i, <8 x i16> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  %vmovl.i111 = sext <4 x i16> %shuffle.i113 to <4 x i32>
  %vmovl.i110 = sext <4 x i16> %shuffle.i115 to <4 x i32>
  %vmovl.i109 = sext <4 x i16> %shuffle.i112 to <4 x i32>
  %vmovl.i108 = sext <4 x i16> %shuffle.i114 to <4 x i32>
  %add.ptr29 = getelementptr i8, ptr null, i64 16
  %add.ptr32 = getelementptr i8, ptr null, i64 32
  %add.ptr35 = getelementptr i8, ptr null, i64 48
  store <4 x i32> %vmovl.i111, ptr null, align 4
  store <4 x i32> %vmovl.i110, ptr %add.ptr29, align 4
  store <4 x i32> %vmovl.i109, ptr %add.ptr32, align 4
  store <4 x i32> %vmovl.i108, ptr %add.ptr35, align 4
  ret void
}

define void @test11(<2 x i64> %0, i64 %1, <2 x i64> %2) {
; CHECK-LABEL: @test11(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP3:%.*]] = insertelement <2 x i64> [[TMP0:%.*]], i64 [[TMP1:%.*]], i32 1
; CHECK-NEXT:    [[TMP4:%.*]] = add <2 x i64> <i64 5, i64 0>, [[TMP2:%.*]]
; CHECK-NEXT:    [[TMP5:%.*]] = trunc <2 x i64> [[TMP4]] to <2 x i16>
; CHECK-NEXT:    [[TMP6:%.*]] = shufflevector <2 x i16> [[TMP5]], <2 x i16> poison, <4 x i32> <i32 0, i32 1, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP7:%.*]] = trunc <2 x i64> [[TMP3]] to <2 x i16>
; CHECK-NEXT:    [[TMP10:%.*]] = shufflevector <2 x i16> [[TMP7]], <2 x i16> poison, <4 x i32> <i32 0, i32 1, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP8:%.*]] = shufflevector <4 x i16> [[TMP6]], <4 x i16> [[TMP10]], <4 x i32> <i32 0, i32 1, i32 4, i32 5>
; CHECK-NEXT:    [[TMP9:%.*]] = trunc <4 x i16> [[TMP8]] to <4 x i8>
; CHECK-NEXT:    [[TMP11:%.*]] = urem <4 x i8> [[TMP9]], zeroinitializer
; CHECK-NEXT:    [[TMP12:%.*]] = icmp ne <4 x i8> [[TMP11]], zeroinitializer
; CHECK-NEXT:    ret void
;
entry:
  %3 = insertelement <2 x i64> %0, i64 %1, i32 1
  %4 = add <2 x i64> <i64 5, i64 0>, %2
  %5 = trunc <2 x i64> %3 to <2 x i8>
  %6 = trunc <2 x i64> %4 to <2 x i8>
  %7 = urem <2 x i8> %5, zeroinitializer
  %8 = urem <2 x i8> %6, zeroinitializer
  %9 = icmp ne <2 x i8> %7, zeroinitializer
  %10 = icmp ne <2 x i8> %8, zeroinitializer
  ret void
}

define void @test12() {
; CHECK-LABEL: @test12(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = getelementptr float, ptr null, i64 33
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr float, ptr null, i64 50
; CHECK-NEXT:    [[TMP2:%.*]] = getelementptr float, ptr null, i64 75
; CHECK-NEXT:    [[TMP3:%.*]] = load <8 x float>, ptr [[TMP1]], align 4
; CHECK-NEXT:    [[TMP4:%.*]] = load <8 x float>, ptr [[TMP2]], align 4
; CHECK-NEXT:    [[TMP5:%.*]] = load <16 x float>, ptr [[TMP0]], align 4
; CHECK-NEXT:    [[TMP6:%.*]] = shufflevector <8 x float> [[TMP4]], <8 x float> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP7:%.*]] = shufflevector <8 x float> [[TMP3]], <8 x float> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP10:%.*]] = shufflevector <32 x float> [[TMP6]], <32 x float> [[TMP7]], <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 32, i32 33, i32 34, i32 35, i32 36, i32 37, i32 38, i32 39, i32 16, i32 17, i32 18, i32 19, i32 20, i32 21, i32 22, i32 23, i32 24, i32 25, i32 26, i32 27, i32 28, i32 29, i32 30, i32 31>
; CHECK-NEXT:    [[TMP11:%.*]] = shufflevector <16 x float> [[TMP5]], <16 x float> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP8:%.*]] = shufflevector <32 x float> [[TMP10]], <32 x float> [[TMP11]], <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 32, i32 33, i32 34, i32 35, i32 36, i32 37, i32 38, i32 39, i32 40, i32 41, i32 42, i32 43, i32 44, i32 45, i32 46, i32 47>
; CHECK-NEXT:    [[TMP9:%.*]] = fpext <32 x float> [[TMP8]] to <32 x double>
; CHECK-NEXT:    [[TMP14:%.*]] = fadd <32 x double> zeroinitializer, [[TMP9]]
; CHECK-NEXT:    [[TMP15:%.*]] = fptrunc <32 x double> [[TMP14]] to <32 x float>
; CHECK-NEXT:    [[TMP16:%.*]] = fcmp ogt <32 x float> zeroinitializer, [[TMP15]]
; CHECK-NEXT:    ret void
;
entry:
  %0 = getelementptr float, ptr null, i64 33
  %1 = getelementptr float, ptr null, i64 41
  %2 = getelementptr float, ptr null, i64 50
  %3 = getelementptr float, ptr null, i64 75
  %4 = load <8 x float>, ptr %0, align 4
  %5 = load <8 x float>, ptr %1, align 4
  %6 = load <8 x float>, ptr %2, align 4
  %7 = load <8 x float>, ptr %3, align 4
  %8 = fpext <8 x float> %4 to <8 x double>
  %9 = fpext <8 x float> %5 to <8 x double>
  %10 = fpext <8 x float> %6 to <8 x double>
  %11 = fpext <8 x float> %7 to <8 x double>
  %12 = fadd <8 x double> zeroinitializer, %8
  %13 = fadd <8 x double> zeroinitializer, %9
  %14 = fadd <8 x double> zeroinitializer, %10
  %15 = fadd <8 x double> zeroinitializer, %11
  %16 = fptrunc <8 x double> %12 to <8 x float>
  %17 = fptrunc <8 x double> %13 to <8 x float>
  %18 = fptrunc <8 x double> %14 to <8 x float>
  %19 = fptrunc <8 x double> %15 to <8 x float>
  %20 = fcmp ogt <8 x float> zeroinitializer, %16
  %21 = fcmp ogt <8 x float> zeroinitializer, %17
  %22 = fcmp ogt <8 x float> zeroinitializer, %18
  %23 = fcmp ogt <8 x float> zeroinitializer, %19
  ret void
}

define void @test13(<8 x i32> %0, ptr %out0, ptr %out1, ptr %out2) {
; CHECK-LABEL: @test13(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP1:%.*]] = shufflevector <8 x i32> [[TMP0:%.*]], <8 x i32> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    [[TMP3:%.*]] = shufflevector <8 x i32> [[TMP0]], <8 x i32> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    br label [[FOR_END_LOOPEXIT:%.*]]
; CHECK:       for.end.loopexit:
; CHECK-NEXT:    [[TMP4:%.*]] = phi <16 x i32> [ [[TMP3]], [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[TMP6:%.*]] = shufflevector <16 x i32> [[TMP4]], <16 x i32> poison, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    [[OR0:%.*]] = or <4 x i32> [[TMP6]], zeroinitializer
; CHECK-NEXT:    store <4 x i32> [[OR0]], ptr [[OUT0:%.*]], align 4
; CHECK-NEXT:    [[TMP7:%.*]] = shufflevector <16 x i32> [[TMP3]], <16 x i32> poison, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
; CHECK-NEXT:    store <4 x i32> [[TMP7]], ptr [[OUT1:%.*]], align 4
; CHECK-NEXT:    [[TMP8:%.*]] = shufflevector <16 x i32> [[TMP3]], <16 x i32> poison, <4 x i32> <i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    store <4 x i32> [[TMP8]], ptr [[OUT2:%.*]], align 4
; CHECK-NEXT:    ret void
;
entry:
  %1 = shufflevector <8 x i32> %0, <8 x i32> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %2 = shufflevector <8 x i32> %0, <8 x i32> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  %3 = shufflevector <8 x i32> %0, <8 x i32> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %4 = shufflevector <8 x i32> %0, <8 x i32> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  br label %for.end.loopexit

for.end.loopexit:
  %phi0 = phi <4 x i32> [ %1, %entry ]
  %phi1 = phi <4 x i32> [ %2, %entry ]
  %phi2 = phi <4 x i32> [ %3, %entry ]
  %phi3 = phi <4 x i32> [ %4, %entry ]
  %or0 = or <4 x i32> %phi1, zeroinitializer
  store <4 x i32> %or0, ptr %out0, align 4
  store <4 x i32> %1, ptr %out1, align 4
  store <4 x i32> %4, ptr %out2, align 4
  ret void
}

define void @test14(<8 x i1> %0) {
; CHECK-LABEL: @test14(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP2:%.*]] = shufflevector <8 x i1> [[TMP0:%.*]], <8 x i1> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    [[TMP3:%.*]] = sext <16 x i1> [[TMP2]] to <16 x i16>
; CHECK-NEXT:    [[TMP4:%.*]] = shufflevector <16 x i16> [[TMP3]], <16 x i16> poison, <32 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    [[TMP5:%.*]] = shufflevector <16 x i16> [[TMP3]], <16 x i16> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 8, i32 9, i32 10, i32 11, i32 12, i32 13, i32 14, i32 15>
; CHECK-NEXT:    br label [[FOR_END_LOOPEXIT:%.*]]
; CHECK:       for.end.loopexit:
; CHECK-NEXT:    [[TMP6:%.*]] = phi <16 x i16> [ [[TMP5]], [[ENTRY:%.*]] ]
; CHECK-NEXT:    [[TMP8:%.*]] = shufflevector <16 x i16> [[TMP6]], <16 x i16> poison, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
; CHECK-NEXT:    [[OR0:%.*]] = or <4 x i16> [[TMP8]], zeroinitializer
; CHECK-NEXT:    ret void
;
entry:
  %sext0 = sext <8 x i1> %0 to <8 x i16>
  %sext1 = sext <8 x i1> %0 to <8 x i16>
  %1 = shufflevector <8 x i16> %sext0, <8 x i16> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %2 = shufflevector <8 x i16> %sext0, <8 x i16> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  %3 = shufflevector <8 x i16> %sext1, <8 x i16> zeroinitializer, <4 x i32> <i32 0, i32 1, i32 2, i32 3>
  %4 = shufflevector <8 x i16> %sext1, <8 x i16> zeroinitializer, <4 x i32> <i32 4, i32 5, i32 6, i32 7>
  br label %for.end.loopexit

for.end.loopexit:
  %phi0 = phi <4 x i16> [ %1, %entry ]
  %phi1 = phi <4 x i16> [ %2, %entry ]
  %phi2 = phi <4 x i16> [ %3, %entry ]
  %phi3 = phi <4 x i16> [ %4, %entry ]
  %or0 = or <4 x i16> %phi1, zeroinitializer
  ret void
}

define i32 @test15() {
; CHECK-LABEL: @test15(
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[TMP0:%.*]] = getelementptr i8, ptr null, i64 480
; CHECK-NEXT:    [[TMP1:%.*]] = getelementptr i8, ptr null, i64 160
; CHECK-NEXT:    [[TMP2:%.*]] = load <8 x float>, ptr [[TMP1]], align 16
; CHECK-NEXT:    [[TMP3:%.*]] = load <4 x float>, ptr [[TMP1]], align 16
; CHECK-NEXT:    store <4 x float> [[TMP3]], ptr null, align 16
; CHECK-NEXT:    [[TMP10:%.*]] = shufflevector <8 x float> [[TMP2]], <8 x float> poison, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison, i32 poison>
; CHECK-NEXT:    [[TMP5:%.*]] = shufflevector <16 x float> [[TMP10]], <16 x float> <float undef, float undef, float undef, float undef, float undef, float undef, float undef, float undef, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00>, <16 x i32> <i32 0, i32 1, i32 2, i32 3, i32 4, i32 5, i32 6, i32 7, i32 24, i32 25, i32 26, i32 27, i32 28, i32 29, i32 30, i32 31>
; CHECK-NEXT:    [[TMP12:%.*]] = fadd <16 x float> zeroinitializer, [[TMP5]]
; CHECK-NEXT:    store <16 x float> [[TMP12]], ptr [[TMP0]], align 16
; CHECK-NEXT:    ret i32 0
;
entry:
  %0 = getelementptr i8, ptr null, i64 512
  %1 = getelementptr i8, ptr null, i64 528
  %2 = getelementptr i8, ptr null, i64 480
  %3 = getelementptr i8, ptr null, i64 496
  %4 = getelementptr i8, ptr null, i64 160
  %5 = load <4 x float>, ptr %4, align 16
  %6 = getelementptr i8, ptr null, i64 176
  %7 = load <4 x float>, ptr %6, align 16
  store <4 x float> %5, ptr null, align 16
  %8 = fadd <4 x float> zeroinitializer, %5
  %9 = fadd <4 x float> zeroinitializer, %7
  store <4 x float> %8, ptr %2, align 16
  store <4 x float> %9, ptr %3, align 16
  %10 = fadd <4 x float> zeroinitializer, zeroinitializer
  %11 = fadd <4 x float> zeroinitializer, zeroinitializer
  store <4 x float> %10, ptr %0, align 16
  store <4 x float> %11, ptr %1, align 16
  ret i32 0
}

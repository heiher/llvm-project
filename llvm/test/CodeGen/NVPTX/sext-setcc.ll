; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 5
; RUN: llc < %s -mtriple=nvptx64 -mcpu=sm_80 | FileCheck %s
; RUN: %if ptxas-11.0 %{ llc < %s -mtriple=nvptx64 -mcpu=sm_80 -mattr=+ptx70 | %ptxas-verify -arch=sm_80 %}

define <2 x i16> @sext_setcc_v2i1_to_v2i16(ptr %p) {
; CHECK-LABEL: sext_setcc_v2i1_to_v2i16(
; CHECK:       {
; CHECK-NEXT:    .reg .pred %p<3>;
; CHECK-NEXT:    .reg .b16 %rs<5>;
; CHECK-NEXT:    .reg .b64 %rd<2>;
; CHECK-EMPTY:
; CHECK-NEXT:  // %bb.0: // %entry
; CHECK-NEXT:    ld.param.b64 %rd1, [sext_setcc_v2i1_to_v2i16_param_0];
; CHECK-NEXT:    ld.v2.b16 {%rs1, %rs2}, [%rd1];
; CHECK-NEXT:    setp.eq.b16 %p1, %rs1, 0;
; CHECK-NEXT:    setp.eq.b16 %p2, %rs2, 0;
; CHECK-NEXT:    selp.b16 %rs3, -1, 0, %p2;
; CHECK-NEXT:    selp.b16 %rs4, -1, 0, %p1;
; CHECK-NEXT:    st.param.v2.b16 [func_retval0], {%rs4, %rs3};
; CHECK-NEXT:    ret;
entry:
  %v = load <2 x i16>, ptr %p, align 4
  %cmp = icmp eq <2 x i16> %v, zeroinitializer
  %sext = sext <2 x i1> %cmp to <2 x i16>
  ret <2 x i16> %sext
}

define <4 x i8> @sext_setcc_v4i1_to_v4i8(ptr %p) {
; CHECK-LABEL: sext_setcc_v4i1_to_v4i8(
; CHECK:       {
; CHECK-NEXT:    .reg .pred %p<5>;
; CHECK-NEXT:    .reg .b16 %rs<9>;
; CHECK-NEXT:    .reg .b32 %r<13>;
; CHECK-NEXT:    .reg .b64 %rd<2>;
; CHECK-EMPTY:
; CHECK-NEXT:  // %bb.0: // %entry
; CHECK-NEXT:    ld.param.b64 %rd1, [sext_setcc_v4i1_to_v4i8_param_0];
; CHECK-NEXT:    ld.b32 %r1, [%rd1];
; CHECK-NEXT:    bfe.u32 %r2, %r1, 0, 8;
; CHECK-NEXT:    cvt.u16.u32 %rs1, %r2;
; CHECK-NEXT:    and.b16 %rs2, %rs1, 255;
; CHECK-NEXT:    setp.eq.b16 %p1, %rs2, 0;
; CHECK-NEXT:    bfe.u32 %r3, %r1, 8, 8;
; CHECK-NEXT:    cvt.u16.u32 %rs3, %r3;
; CHECK-NEXT:    and.b16 %rs4, %rs3, 255;
; CHECK-NEXT:    setp.eq.b16 %p2, %rs4, 0;
; CHECK-NEXT:    bfe.u32 %r4, %r1, 16, 8;
; CHECK-NEXT:    cvt.u16.u32 %rs5, %r4;
; CHECK-NEXT:    and.b16 %rs6, %rs5, 255;
; CHECK-NEXT:    setp.eq.b16 %p3, %rs6, 0;
; CHECK-NEXT:    bfe.u32 %r5, %r1, 24, 8;
; CHECK-NEXT:    cvt.u16.u32 %rs7, %r5;
; CHECK-NEXT:    and.b16 %rs8, %rs7, 255;
; CHECK-NEXT:    setp.eq.b16 %p4, %rs8, 0;
; CHECK-NEXT:    selp.b32 %r6, -1, 0, %p4;
; CHECK-NEXT:    selp.b32 %r7, -1, 0, %p3;
; CHECK-NEXT:    prmt.b32 %r8, %r7, %r6, 0x3340U;
; CHECK-NEXT:    selp.b32 %r9, -1, 0, %p2;
; CHECK-NEXT:    selp.b32 %r10, -1, 0, %p1;
; CHECK-NEXT:    prmt.b32 %r11, %r10, %r9, 0x3340U;
; CHECK-NEXT:    prmt.b32 %r12, %r11, %r8, 0x5410U;
; CHECK-NEXT:    st.param.b32 [func_retval0], %r12;
; CHECK-NEXT:    ret;
entry:
  %v = load <4 x i8>, ptr %p, align 4
  %cmp = icmp eq <4 x i8> %v, zeroinitializer
  %sext = sext <4 x i1> %cmp to <4 x i8>
  ret <4 x i8> %sext
}

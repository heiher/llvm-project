; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=riscv32 -mattr=+v,+f,+d,+zvfhmin,+zvfbfmin -target-abi=ilp32d \
; RUN:     -verify-machineinstrs < %s | FileCheck %s
; RUN: llc -mtriple=riscv64 -mattr=+v,+f,+d,+zvfhmin,+zvfbfmin -target-abi=lp64d \
; RUN:     -verify-machineinstrs < %s | FileCheck %s

define <vscale x 1 x i64> @llround_nxv1i64_nxv1f32(<vscale x 1 x float> %x) {
; CHECK-LABEL: llround_nxv1i64_nxv1f32:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e32, mf2, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v9, v8
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    vmv1r.v v8, v9
; CHECK-NEXT:    ret
  %a = call <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f32(<vscale x 1 x float> %x)
  ret <vscale x 1 x i64> %a
}
declare <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f32(<vscale x 1 x float>)

define <vscale x 2 x i64> @llround_nxv2i64_nxv2f32(<vscale x 2 x float> %x) {
; CHECK-LABEL: llround_nxv2i64_nxv2f32:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e32, m1, ta, ma
; CHECK-NEXT:    vmv1r.v v10, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vfwcvt.x.f.v v8, v10
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f32(<vscale x 2 x float> %x)
  ret <vscale x 2 x i64> %a
}
declare <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f32(<vscale x 2 x float>)

define <vscale x 4 x i64> @llround_nxv4i64_nxv4f32(<vscale x 4 x float> %x) {
; CHECK-LABEL: llround_nxv4i64_nxv4f32:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e32, m2, ta, ma
; CHECK-NEXT:    vmv2r.v v12, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vfwcvt.x.f.v v8, v12
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f32(<vscale x 4 x float> %x)
  ret <vscale x 4 x i64> %a
}
declare <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f32(<vscale x 4 x float>)

define <vscale x 8 x i64> @llround_nxv8i64_nxv8f32(<vscale x 8 x float> %x) {
; CHECK-LABEL: llround_nxv8i64_nxv8f32:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e32, m4, ta, ma
; CHECK-NEXT:    vmv4r.v v16, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vfwcvt.x.f.v v8, v16
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f32(<vscale x 8 x float> %x)
  ret <vscale x 8 x i64> %a
}
declare <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f32(<vscale x 8 x float>)

define <vscale x 16 x i64> @llround_nxv16i64_nxv16f32(<vscale x 16 x float> %x) {
; CHECK-LABEL: llround_nxv16i64_nxv16f32:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e32, m4, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v24, v8
; CHECK-NEXT:    vfwcvt.x.f.v v16, v12
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    vmv8r.v v8, v24
; CHECK-NEXT:    ret
  %a = call <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16f32(<vscale x 16 x float> %x)
  ret <vscale x 16 x i64> %a
}
declare <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16f32(<vscale x 16 x float>)

define <vscale x 1 x i64> @llround_nxv1i64_nxv1f64(<vscale x 1 x double> %x) {
; CHECK-LABEL: llround_nxv1i64_nxv1f64:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e64, m1, ta, ma
; CHECK-NEXT:    vfcvt.x.f.v v8, v8
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f64(<vscale x 1 x double> %x)
  ret <vscale x 1 x i64> %a
}
declare <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f64(<vscale x 1 x double>)

define <vscale x 2 x i64> @llround_nxv2i64_nxv2f64(<vscale x 2 x double> %x) {
; CHECK-LABEL: llround_nxv2i64_nxv2f64:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e64, m2, ta, ma
; CHECK-NEXT:    vfcvt.x.f.v v8, v8
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f64(<vscale x 2 x double> %x)
  ret <vscale x 2 x i64> %a
}
declare <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f64(<vscale x 2 x double>)

define <vscale x 4 x i64> @llround_nxv4i64_nxv4f64(<vscale x 4 x double> %x) {
; CHECK-LABEL: llround_nxv4i64_nxv4f64:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e64, m4, ta, ma
; CHECK-NEXT:    vfcvt.x.f.v v8, v8
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f64(<vscale x 4 x double> %x)
  ret <vscale x 4 x i64> %a
}
declare <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f64(<vscale x 4 x double>)

define <vscale x 8 x i64> @llround_nxv8i64_nxv8f64(<vscale x 8 x double> %x) {
; CHECK-LABEL: llround_nxv8i64_nxv8f64:
; CHECK:       # %bb.0:
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli a1, zero, e64, m8, ta, ma
; CHECK-NEXT:    vfcvt.x.f.v v8, v8
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f64(<vscale x 8 x double> %x)
  ret <vscale x 8 x i64> %a
}
declare <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f64(<vscale x 8 x double>)

define <vscale x 1 x i64> @llround_nxv1f16(<vscale x 1 x half> %x) {
; CHECK-LABEL: llround_nxv1f16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, mf4, ta, ma
; CHECK-NEXT:    vfwcvt.f.f.v v9, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, mf2, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v9
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f16(<vscale x 1 x half> %x)
  ret <vscale x 1 x i64> %a
}
declare <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1f16(<vscale x 1 x half>)

define <vscale x 2 x i64> @llround_nxv2f16(<vscale x 2 x half> %x) {
; CHECK-LABEL: llround_nxv2f16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, mf2, ta, ma
; CHECK-NEXT:    vfwcvt.f.f.v v10, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m1, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v10
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f16(<vscale x 2 x half> %x)
  ret <vscale x 2 x i64> %a
}
declare <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2f16(<vscale x 2 x half>)

define <vscale x 4 x i64> @llround_nxv4f16(<vscale x 4 x half> %x) {
; CHECK-LABEL: llround_nxv4f16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m1, ta, ma
; CHECK-NEXT:    vfwcvt.f.f.v v12, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m2, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v12
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f16(<vscale x 4 x half> %x)
  ret <vscale x 4 x i64> %a
}
declare <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4f16(<vscale x 4 x half>)

define <vscale x 8 x i64> @llround_nxv8f16(<vscale x 8 x half> %x) {
; CHECK-LABEL: llround_nxv8f16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m2, ta, ma
; CHECK-NEXT:    vfwcvt.f.f.v v16, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m4, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v16
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f16(<vscale x 8 x half> %x)
  ret <vscale x 8 x i64> %a
}
declare <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8f16(<vscale x 8 x half>)

define <vscale x 16 x i64> @llround_nxv16f16(<vscale x 16 x half> %x) {
; CHECK-LABEL: llround_nxv16f16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m2, ta, ma
; CHECK-NEXT:    vfwcvt.f.f.v v16, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vfwcvt.f.f.v v24, v10
; CHECK-NEXT:    vsetvli zero, zero, e32, m4, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v16
; CHECK-NEXT:    vfwcvt.x.f.v v16, v24
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16f16(<vscale x 16 x half> %x)
  ret <vscale x 16 x i64> %a
}
declare <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16f16(<vscale x 16 x half>)

define <vscale x 1 x i64> @llround_nxv1bf16(<vscale x 1 x bfloat> %x) {
; CHECK-LABEL: llround_nxv1bf16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, mf4, ta, ma
; CHECK-NEXT:    vfwcvtbf16.f.f.v v9, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, mf2, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v9
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1bf16(<vscale x 1 x bfloat> %x)
  ret <vscale x 1 x i64> %a
}
declare <vscale x 1 x i64> @llvm.llround.nxv1i64.nxv1bf16(<vscale x 1 x bfloat>)

define <vscale x 2 x i64> @llround_nxv2bf16(<vscale x 2 x bfloat> %x) {
; CHECK-LABEL: llround_nxv2bf16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, mf2, ta, ma
; CHECK-NEXT:    vfwcvtbf16.f.f.v v10, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m1, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v10
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2bf16(<vscale x 2 x bfloat> %x)
  ret <vscale x 2 x i64> %a
}
declare <vscale x 2 x i64> @llvm.llround.nxv2i64.nxv2bf16(<vscale x 2 x bfloat>)

define <vscale x 4 x i64> @llround_nxv4bf16(<vscale x 4 x bfloat> %x) {
; CHECK-LABEL: llround_nxv4bf16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m1, ta, ma
; CHECK-NEXT:    vfwcvtbf16.f.f.v v12, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m2, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v12
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4bf16(<vscale x 4 x bfloat> %x)
  ret <vscale x 4 x i64> %a
}
declare <vscale x 4 x i64> @llvm.llround.nxv4i64.nxv4bf16(<vscale x 4 x bfloat>)

define <vscale x 8 x i64> @llround_nxv8bf16(<vscale x 8 x bfloat> %x) {
; CHECK-LABEL: llround_nxv8bf16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m2, ta, ma
; CHECK-NEXT:    vfwcvtbf16.f.f.v v16, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vsetvli zero, zero, e32, m4, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v16
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8bf16(<vscale x 8 x bfloat> %x)
  ret <vscale x 8 x i64> %a
}
declare <vscale x 8 x i64> @llvm.llround.nxv8i64.nxv8bf16(<vscale x 8 x bfloat>)

define <vscale x 16 x i64> @llround_nxv16bf16(<vscale x 16 x bfloat> %x) {
; CHECK-LABEL: llround_nxv16bf16:
; CHECK:       # %bb.0:
; CHECK-NEXT:    vsetvli a0, zero, e16, m2, ta, ma
; CHECK-NEXT:    vfwcvtbf16.f.f.v v16, v8
; CHECK-NEXT:    fsrmi a0, 4
; CHECK-NEXT:    vfwcvtbf16.f.f.v v24, v10
; CHECK-NEXT:    vsetvli zero, zero, e32, m4, ta, ma
; CHECK-NEXT:    vfwcvt.x.f.v v8, v16
; CHECK-NEXT:    vfwcvt.x.f.v v16, v24
; CHECK-NEXT:    fsrm a0
; CHECK-NEXT:    ret
  %a = call <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16bf16(<vscale x 16 x bfloat> %x)
  ret <vscale x 16 x i64> %a
}
declare <vscale x 16 x i64> @llvm.llround.nxv16i64.nxv16bf16(<vscale x 16 x bfloat>)

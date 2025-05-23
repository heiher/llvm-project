; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 5
; RUN:  llc -amdgpu-scalarize-global-loads=false -march=amdgcn < %s | FileCheck --check-prefixes=SI,FUNC %s
; RUN:  llc -amdgpu-scalarize-global-loads=false -march=amdgcn -mcpu=tonga < %s | FileCheck --check-prefixes=VI,FUNC %s

define amdgpu_kernel void @fneg_fabsf_fadd_f32(ptr addrspace(1) %out, float %x, float %y) {
; SI-LABEL: fneg_fabsf_fadd_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_mov_b32 s4, s0
; SI-NEXT:    s_mov_b32 s5, s1
; SI-NEXT:    v_mov_b32_e32 v0, s2
; SI-NEXT:    v_sub_f32_e64 v0, s3, |v0|
; SI-NEXT:    buffer_store_dword v0, off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_fadd_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    v_mov_b32_e32 v0, s2
; VI-NEXT:    v_sub_f32_e64 v2, s3, |v0|
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %fabs = call float @llvm.fabs.f32(float %x)
  %fsub = fsub float -0.000000e+00, %fabs
  %fadd = fadd float %y, %fsub
  store float %fadd, ptr addrspace(1) %out, align 4
  ret void
}

define amdgpu_kernel void @fneg_fabsf_fmul_f32(ptr addrspace(1) %out, float %x, float %y) {
; SI-LABEL: fneg_fabsf_fmul_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_mov_b32 s4, s0
; SI-NEXT:    s_mov_b32 s5, s1
; SI-NEXT:    v_mov_b32_e32 v0, s2
; SI-NEXT:    v_mul_f32_e64 v0, s3, -|v0|
; SI-NEXT:    buffer_store_dword v0, off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_fmul_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    v_mov_b32_e32 v0, s2
; VI-NEXT:    v_mul_f32_e64 v2, s3, -|v0|
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %fabs = call float @llvm.fabs.f32(float %x)
  %fsub = fsub float -0.000000e+00, %fabs
  %fmul = fmul float %y, %fsub
  store float %fmul, ptr addrspace(1) %out, align 4
  ret void
}

define amdgpu_kernel void @fneg_fabsf_free_f32(ptr addrspace(1) %out, i32 %in) {
; SI-LABEL: fneg_fabsf_free_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dword s2, s[4:5], 0xb
; SI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s3, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_or_b32 s4, s2, 0x80000000
; SI-NEXT:    s_mov_b32 s2, -1
; SI-NEXT:    v_mov_b32_e32 v0, s4
; SI-NEXT:    buffer_store_dword v0, off, s[0:3], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_free_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dword s2, s[4:5], 0x2c
; VI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    s_bitset1_b32 s2, 31
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    v_mov_b32_e32 v2, s2
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %bc = bitcast i32 %in to float
  %fabs = call float @llvm.fabs.f32(float %bc)
  %fsub = fsub float -0.000000e+00, %fabs
  store float %fsub, ptr addrspace(1) %out
  ret void
}

define amdgpu_kernel void @fneg_fabsf_fn_free_f32(ptr addrspace(1) %out, i32 %in) {
; SI-LABEL: fneg_fabsf_fn_free_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dword s2, s[4:5], 0xb
; SI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s3, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_or_b32 s4, s2, 0x80000000
; SI-NEXT:    s_mov_b32 s2, -1
; SI-NEXT:    v_mov_b32_e32 v0, s4
; SI-NEXT:    buffer_store_dword v0, off, s[0:3], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_fn_free_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dword s2, s[4:5], 0x2c
; VI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    s_bitset1_b32 s2, 31
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    v_mov_b32_e32 v2, s2
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %bc = bitcast i32 %in to float
  %fabs = call float @fabsf(float %bc)
  %fsub = fsub float -0.000000e+00, %fabs
  store float %fsub, ptr addrspace(1) %out
  ret void
}

define amdgpu_kernel void @fneg_fabsf_f32(ptr addrspace(1) %out, float %in) {
; SI-LABEL: fneg_fabsf_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dword s2, s[4:5], 0xb
; SI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s3, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_or_b32 s4, s2, 0x80000000
; SI-NEXT:    s_mov_b32 s2, -1
; SI-NEXT:    v_mov_b32_e32 v0, s4
; SI-NEXT:    buffer_store_dword v0, off, s[0:3], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dword s2, s[4:5], 0x2c
; VI-NEXT:    s_load_dwordx2 s[0:1], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    s_bitset1_b32 s2, 31
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    v_mov_b32_e32 v2, s2
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %fabs = call float @llvm.fabs.f32(float %in)
  %fsub = fsub float -0.000000e+00, %fabs
  store float %fsub, ptr addrspace(1) %out, align 4
  ret void
}

define amdgpu_kernel void @v_fneg_fabsf_f32(ptr addrspace(1) %out, ptr addrspace(1) %in) {
; SI-LABEL: v_fneg_fabsf_f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_mov_b32 s10, s6
; SI-NEXT:    s_mov_b32 s11, s7
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_mov_b32 s8, s2
; SI-NEXT:    s_mov_b32 s9, s3
; SI-NEXT:    buffer_load_dword v0, off, s[8:11], 0
; SI-NEXT:    s_mov_b32 s4, s0
; SI-NEXT:    s_mov_b32 s5, s1
; SI-NEXT:    s_waitcnt vmcnt(0)
; SI-NEXT:    v_or_b32_e32 v0, 0x80000000, v0
; SI-NEXT:    buffer_store_dword v0, off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: v_fneg_fabsf_f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    v_mov_b32_e32 v0, s2
; VI-NEXT:    v_mov_b32_e32 v1, s3
; VI-NEXT:    flat_load_dword v2, v[0:1]
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    s_waitcnt vmcnt(0)
; VI-NEXT:    v_or_b32_e32 v2, 0x80000000, v2
; VI-NEXT:    flat_store_dword v[0:1], v2
; VI-NEXT:    s_endpgm
  %val = load float, ptr addrspace(1) %in, align 4
  %fabs = call float @llvm.fabs.f32(float %val)
  %fsub = fsub float -0.000000e+00, %fabs
  store float %fsub, ptr addrspace(1) %out, align 4
  ret void
}

define amdgpu_kernel void @fneg_fabsf_v2f32(ptr addrspace(1) %out, <2 x float> %in) {
; SI-LABEL: fneg_fabsf_v2f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_bitset1_b32 s3, 31
; SI-NEXT:    s_bitset1_b32 s2, 31
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    s_mov_b32 s4, s0
; SI-NEXT:    s_mov_b32 s5, s1
; SI-NEXT:    v_mov_b32_e32 v0, s2
; SI-NEXT:    v_mov_b32_e32 v1, s3
; SI-NEXT:    buffer_store_dwordx2 v[0:1], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_v2f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    s_bitset1_b32 s3, 31
; VI-NEXT:    s_bitset1_b32 s2, 31
; VI-NEXT:    v_mov_b32_e32 v3, s1
; VI-NEXT:    v_mov_b32_e32 v0, s2
; VI-NEXT:    v_mov_b32_e32 v1, s3
; VI-NEXT:    v_mov_b32_e32 v2, s0
; VI-NEXT:    flat_store_dwordx2 v[2:3], v[0:1]
; VI-NEXT:    s_endpgm
  %fabs = call <2 x float> @llvm.fabs.v2f32(<2 x float> %in)
  %fsub = fsub <2 x float> <float -0.000000e+00, float -0.000000e+00>, %fabs
  store <2 x float> %fsub, ptr addrspace(1) %out
  ret void
}

define amdgpu_kernel void @fneg_fabsf_v4f32(ptr addrspace(1) %out, <4 x float> %in) {
; SI-LABEL: fneg_fabsf_v4f32:
; SI:       ; %bb.0:
; SI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0xd
; SI-NEXT:    s_load_dwordx2 s[4:5], s[4:5], 0x9
; SI-NEXT:    s_mov_b32 s7, 0xf000
; SI-NEXT:    s_waitcnt lgkmcnt(0)
; SI-NEXT:    s_bitset1_b32 s3, 31
; SI-NEXT:    s_bitset1_b32 s2, 31
; SI-NEXT:    s_bitset1_b32 s1, 31
; SI-NEXT:    s_bitset1_b32 s0, 31
; SI-NEXT:    s_mov_b32 s6, -1
; SI-NEXT:    v_mov_b32_e32 v0, s0
; SI-NEXT:    v_mov_b32_e32 v1, s1
; SI-NEXT:    v_mov_b32_e32 v2, s2
; SI-NEXT:    v_mov_b32_e32 v3, s3
; SI-NEXT:    buffer_store_dwordx4 v[0:3], off, s[4:7], 0
; SI-NEXT:    s_endpgm
;
; VI-LABEL: fneg_fabsf_v4f32:
; VI:       ; %bb.0:
; VI-NEXT:    s_load_dwordx4 s[0:3], s[4:5], 0x34
; VI-NEXT:    s_load_dwordx2 s[4:5], s[4:5], 0x24
; VI-NEXT:    s_waitcnt lgkmcnt(0)
; VI-NEXT:    s_bitset1_b32 s3, 31
; VI-NEXT:    s_bitset1_b32 s2, 31
; VI-NEXT:    s_bitset1_b32 s1, 31
; VI-NEXT:    s_bitset1_b32 s0, 31
; VI-NEXT:    v_mov_b32_e32 v4, s4
; VI-NEXT:    v_mov_b32_e32 v0, s0
; VI-NEXT:    v_mov_b32_e32 v1, s1
; VI-NEXT:    v_mov_b32_e32 v2, s2
; VI-NEXT:    v_mov_b32_e32 v3, s3
; VI-NEXT:    v_mov_b32_e32 v5, s5
; VI-NEXT:    flat_store_dwordx4 v[4:5], v[0:3]
; VI-NEXT:    s_endpgm
  %fabs = call <4 x float> @llvm.fabs.v4f32(<4 x float> %in)
  %fsub = fsub <4 x float> <float -0.000000e+00, float -0.000000e+00, float -0.000000e+00, float -0.000000e+00>, %fabs
  store <4 x float> %fsub, ptr addrspace(1) %out
  ret void
}

declare float @fabsf(float) readnone
declare float @llvm.fabs.f32(float) readnone
declare <2 x float> @llvm.fabs.v2f32(<2 x float>) readnone
declare <4 x float> @llvm.fabs.v4f32(<4 x float>) readnone

;; NOTE: These prefixes are unused and the list is autogenerated. Do not add tests below this line:
; FUNC: {{.*}}

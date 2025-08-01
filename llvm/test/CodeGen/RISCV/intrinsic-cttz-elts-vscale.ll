; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 3
; RUN: llc -mtriple=riscv32 -mattr=+v < %s | FileCheck %s -check-prefix=RV32
; RUN: llc -mtriple=riscv64 -mattr=+v < %s | FileCheck %s -check-prefix=RV64

; WITH VSCALE RANGE

define i32 @ctz_nxv4i32(<vscale x 4 x i32> %a) #0 {
; RV32-LABEL: ctz_nxv4i32:
; RV32:       # %bb.0:
; RV32-NEXT:    csrr a0, vlenb
; RV32-NEXT:    vsetvli a1, zero, e16, m1, ta, ma
; RV32-NEXT:    vid.v v10
; RV32-NEXT:    li a1, -1
; RV32-NEXT:    vsetvli zero, zero, e32, m2, ta, ma
; RV32-NEXT:    vmsne.vi v0, v8, 0
; RV32-NEXT:    srli a0, a0, 1
; RV32-NEXT:    vsetvli zero, zero, e16, m1, ta, ma
; RV32-NEXT:    vmv.v.x v8, a0
; RV32-NEXT:    vmadd.vx v10, a1, v8
; RV32-NEXT:    vmv.v.i v8, 0
; RV32-NEXT:    vmerge.vvm v8, v8, v10, v0
; RV32-NEXT:    vredmaxu.vs v8, v8, v8
; RV32-NEXT:    vmv.x.s a1, v8
; RV32-NEXT:    sub a0, a0, a1
; RV32-NEXT:    slli a0, a0, 16
; RV32-NEXT:    srli a0, a0, 16
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_nxv4i32:
; RV64:       # %bb.0:
; RV64-NEXT:    csrr a0, vlenb
; RV64-NEXT:    vsetvli a1, zero, e16, m1, ta, ma
; RV64-NEXT:    vid.v v10
; RV64-NEXT:    li a1, -1
; RV64-NEXT:    vsetvli zero, zero, e32, m2, ta, ma
; RV64-NEXT:    vmsne.vi v0, v8, 0
; RV64-NEXT:    srli a0, a0, 1
; RV64-NEXT:    vsetvli zero, zero, e16, m1, ta, ma
; RV64-NEXT:    vmv.v.x v8, a0
; RV64-NEXT:    vmadd.vx v10, a1, v8
; RV64-NEXT:    vmv.v.i v8, 0
; RV64-NEXT:    vmerge.vvm v8, v8, v10, v0
; RV64-NEXT:    vredmaxu.vs v8, v8, v8
; RV64-NEXT:    vmv.x.s a1, v8
; RV64-NEXT:    sub a0, a0, a1
; RV64-NEXT:    slli a0, a0, 48
; RV64-NEXT:    srli a0, a0, 48
; RV64-NEXT:    ret
  %res = call i32 @llvm.experimental.cttz.elts.i32.nxv4i32(<vscale x 4 x i32> %a, i1 0)
  ret i32 %res
}

; NO VSCALE RANGE

define i64 @ctz_nxv8i1_no_range(<vscale x 8 x i16> %a) {
; RV32-LABEL: ctz_nxv8i1_no_range:
; RV32:       # %bb.0:
; RV32-NEXT:    addi sp, sp, -48
; RV32-NEXT:    .cfi_def_cfa_offset 48
; RV32-NEXT:    sw ra, 44(sp) # 4-byte Folded Spill
; RV32-NEXT:    .cfi_offset ra, -4
; RV32-NEXT:    csrr a0, vlenb
; RV32-NEXT:    slli a0, a0, 1
; RV32-NEXT:    sub sp, sp, a0
; RV32-NEXT:    .cfi_escape 0x0f, 0x0d, 0x72, 0x00, 0x11, 0x30, 0x22, 0x11, 0x02, 0x92, 0xa2, 0x38, 0x00, 0x1e, 0x22 # sp + 48 + 2 * vlenb
; RV32-NEXT:    addi a0, sp, 32
; RV32-NEXT:    vs2r.v v8, (a0) # vscale x 16-byte Folded Spill
; RV32-NEXT:    csrr a0, vlenb
; RV32-NEXT:    srli a0, a0, 3
; RV32-NEXT:    li a2, 8
; RV32-NEXT:    li a1, 0
; RV32-NEXT:    li a3, 0
; RV32-NEXT:    call __muldi3
; RV32-NEXT:    sw a0, 16(sp)
; RV32-NEXT:    sw a1, 20(sp)
; RV32-NEXT:    addi a2, sp, 16
; RV32-NEXT:    vsetvli a3, zero, e64, m8, ta, ma
; RV32-NEXT:    vlse64.v v16, (a2), zero
; RV32-NEXT:    vid.v v8
; RV32-NEXT:    li a2, -1
; RV32-NEXT:    addi a3, sp, 32
; RV32-NEXT:    vl2r.v v24, (a3) # vscale x 16-byte Folded Reload
; RV32-NEXT:    vsetvli zero, zero, e16, m2, ta, ma
; RV32-NEXT:    vmsne.vi v0, v24, 0
; RV32-NEXT:    vsetvli zero, zero, e64, m8, ta, ma
; RV32-NEXT:    vmadd.vx v8, a2, v16
; RV32-NEXT:    vmv.v.i v16, 0
; RV32-NEXT:    li a2, 32
; RV32-NEXT:    vmerge.vim v16, v16, -1, v0
; RV32-NEXT:    vand.vv v8, v8, v16
; RV32-NEXT:    vredmaxu.vs v8, v8, v8
; RV32-NEXT:    vmv.x.s a3, v8
; RV32-NEXT:    vsetivli zero, 1, e64, m1, ta, ma
; RV32-NEXT:    vsrl.vx v8, v8, a2
; RV32-NEXT:    sltu a2, a0, a3
; RV32-NEXT:    vmv.x.s a4, v8
; RV32-NEXT:    sub a1, a1, a4
; RV32-NEXT:    sub a1, a1, a2
; RV32-NEXT:    sub a0, a0, a3
; RV32-NEXT:    csrr a2, vlenb
; RV32-NEXT:    slli a2, a2, 1
; RV32-NEXT:    add sp, sp, a2
; RV32-NEXT:    .cfi_def_cfa sp, 48
; RV32-NEXT:    lw ra, 44(sp) # 4-byte Folded Reload
; RV32-NEXT:    .cfi_restore ra
; RV32-NEXT:    addi sp, sp, 48
; RV32-NEXT:    .cfi_def_cfa_offset 0
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_nxv8i1_no_range:
; RV64:       # %bb.0:
; RV64-NEXT:    csrr a0, vlenb
; RV64-NEXT:    vsetvli a1, zero, e64, m8, ta, ma
; RV64-NEXT:    vid.v v16
; RV64-NEXT:    li a1, -1
; RV64-NEXT:    vsetvli zero, zero, e16, m2, ta, ma
; RV64-NEXT:    vmsne.vi v0, v8, 0
; RV64-NEXT:    vsetvli zero, zero, e64, m8, ta, ma
; RV64-NEXT:    vmv.v.x v8, a0
; RV64-NEXT:    vmadd.vx v16, a1, v8
; RV64-NEXT:    vmv.v.i v8, 0
; RV64-NEXT:    vmerge.vvm v8, v8, v16, v0
; RV64-NEXT:    vredmaxu.vs v8, v8, v8
; RV64-NEXT:    vmv.x.s a1, v8
; RV64-NEXT:    sub a0, a0, a1
; RV64-NEXT:    ret
  %res = call i64 @llvm.experimental.cttz.elts.i64.nxv8i16(<vscale x 8 x i16> %a, i1 0)
  ret i64 %res
}

define i32 @ctz_nxv16i1(<vscale x 16 x i1> %pg, <vscale x 16 x i1> %a) {
; RV32-LABEL: ctz_nxv16i1:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetvli a0, zero, e8, m2, ta, ma
; RV32-NEXT:    vfirst.m a0, v8
; RV32-NEXT:    bgez a0, .LBB2_2
; RV32-NEXT:  # %bb.1:
; RV32-NEXT:    csrr a0, vlenb
; RV32-NEXT:    slli a0, a0, 1
; RV32-NEXT:  .LBB2_2:
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_nxv16i1:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetvli a0, zero, e8, m2, ta, ma
; RV64-NEXT:    vfirst.m a0, v8
; RV64-NEXT:    bgez a0, .LBB2_2
; RV64-NEXT:  # %bb.1:
; RV64-NEXT:    csrr a0, vlenb
; RV64-NEXT:    slli a0, a0, 1
; RV64-NEXT:  .LBB2_2:
; RV64-NEXT:    ret
  %res = call i32 @llvm.experimental.cttz.elts.i32.nxv16i1(<vscale x 16 x i1> %a, i1 0)
  ret i32 %res
}

define i32 @ctz_nxv16i1_poison(<vscale x 16 x i1> %pg, <vscale x 16 x i1> %a) {
; RV32-LABEL: ctz_nxv16i1_poison:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetvli a0, zero, e8, m2, ta, ma
; RV32-NEXT:    vfirst.m a0, v8
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_nxv16i1_poison:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetvli a0, zero, e8, m2, ta, ma
; RV64-NEXT:    vfirst.m a0, v8
; RV64-NEXT:    ret
  %res = call i32 @llvm.experimental.cttz.elts.i32.nxv16i1(<vscale x 16 x i1> %a, i1 1)
  ret i32 %res
}

define i32 @ctz_v16i1(<16 x i1> %pg, <16 x i1> %a) {
; RV32-LABEL: ctz_v16i1:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli zero, 16, e8, m1, ta, ma
; RV32-NEXT:    vfirst.m a0, v8
; RV32-NEXT:    bgez a0, .LBB4_2
; RV32-NEXT:  # %bb.1:
; RV32-NEXT:    li a0, 16
; RV32-NEXT:  .LBB4_2:
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_v16i1:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli zero, 16, e8, m1, ta, ma
; RV64-NEXT:    vfirst.m a0, v8
; RV64-NEXT:    bgez a0, .LBB4_2
; RV64-NEXT:  # %bb.1:
; RV64-NEXT:    li a0, 16
; RV64-NEXT:  .LBB4_2:
; RV64-NEXT:    ret
  %res = call i32 @llvm.experimental.cttz.elts.i32.v16i1(<16 x i1> %a, i1 0)
  ret i32 %res
}

define i32 @ctz_v16i1_poison(<16 x i1> %pg, <16 x i1> %a) {
; RV32-LABEL: ctz_v16i1_poison:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli zero, 16, e8, m1, ta, ma
; RV32-NEXT:    vfirst.m a0, v8
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_v16i1_poison:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli zero, 16, e8, m1, ta, ma
; RV64-NEXT:    vfirst.m a0, v8
; RV64-NEXT:    ret
  %res = call i32 @llvm.experimental.cttz.elts.i32.v16i1(<16 x i1> %a, i1 1)
  ret i32 %res
}

define i16 @ctz_v8i1_i16_ret(<8 x i1> %a) {
; RV32-LABEL: ctz_v8i1_i16_ret:
; RV32:       # %bb.0:
; RV32-NEXT:    vsetivli zero, 8, e8, mf2, ta, ma
; RV32-NEXT:    vfirst.m a0, v0
; RV32-NEXT:    bgez a0, .LBB6_2
; RV32-NEXT:  # %bb.1:
; RV32-NEXT:    li a0, 8
; RV32-NEXT:  .LBB6_2:
; RV32-NEXT:    ret
;
; RV64-LABEL: ctz_v8i1_i16_ret:
; RV64:       # %bb.0:
; RV64-NEXT:    vsetivli zero, 8, e8, mf2, ta, ma
; RV64-NEXT:    vfirst.m a0, v0
; RV64-NEXT:    bgez a0, .LBB6_2
; RV64-NEXT:  # %bb.1:
; RV64-NEXT:    li a0, 8
; RV64-NEXT:  .LBB6_2:
; RV64-NEXT:    ret
  %res = call i16 @llvm.experimental.cttz.elts.i16.v8i1(<8 x i1> %a, i1 0)
  ret i16 %res
}

declare i64 @llvm.experimental.cttz.elts.i64.nxv8i16(<vscale x 8 x i16>, i1)
declare i32 @llvm.experimental.cttz.elts.i32.nxv16i1(<vscale x 16 x i1>, i1)
declare i32 @llvm.experimental.cttz.elts.i32.nxv4i32(<vscale x 4 x i32>, i1)
declare i32 @llvm.experimental.cttz.elts.i32.v16i1(<16 x i1>, i1)
declare i16 @llvm.experimental.cttz.elts.i16.v16i1(<8 x i1>, i1)

attributes #0 = { vscale_range(2,1024) }

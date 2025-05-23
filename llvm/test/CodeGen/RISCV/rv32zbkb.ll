; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=riscv32 -verify-machineinstrs < %s \
; RUN:   | FileCheck %s -check-prefixes=CHECK,RV32I
; RUN: llc -mtriple=riscv32 -mattr=+zbkb -verify-machineinstrs < %s \
; RUN:   | FileCheck %s -check-prefixes=CHECK,RV32ZBKB

define i32 @pack_i32(i32 %a, i32 %b) nounwind {
; RV32I-LABEL: pack_i32:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    slli a1, a1, 16
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: pack_i32:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    pack a0, a0, a1
; RV32ZBKB-NEXT:    ret
  %shl = and i32 %a, 65535
  %shl1 = shl i32 %b, 16
  %or = or i32 %shl1, %shl
  ret i32 %or
}

define i32 @pack_i32_2(i16 zeroext %a, i16 zeroext %b) nounwind {
; RV32I-LABEL: pack_i32_2:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a1, a1, 16
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: pack_i32_2:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    pack a0, a0, a1
; RV32ZBKB-NEXT:    ret
  %zexta = zext i16 %a to i32
  %zextb = zext i16 %b to i32
  %shl1 = shl i32 %zextb, 16
  %or = or i32 %shl1, %zexta
  ret i32 %or
}

define i32 @pack_i32_3(i16 zeroext %0, i16 zeroext %1, i32 %2) {
; RV32I-LABEL: pack_i32_3:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    or a0, a0, a1
; RV32I-NEXT:    add a0, a0, a2
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: pack_i32_3:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    pack a0, a1, a0
; RV32ZBKB-NEXT:    add a0, a0, a2
; RV32ZBKB-NEXT:    ret
  %4 = zext i16 %0 to i32
  %5 = shl nuw i32 %4, 16
  %6 = zext i16 %1 to i32
  %7 = or i32 %5, %6
  %8 = add i32 %7, %2
  ret i32 %8
}

; As we are not matching directly i64 code patterns on RV32 some i64 patterns
; don't have yet any matching bit manipulation instructions on RV32.
; This test is presented here in case future expansions of the Bitmanip
; extensions introduce instructions suitable for this pattern.

define i64 @pack_i64(i64 %a, i64 %b) nounwind {
; CHECK-LABEL: pack_i64:
; CHECK:       # %bb.0:
; CHECK-NEXT:    mv a1, a2
; CHECK-NEXT:    ret
  %shl = and i64 %a, 4294967295
  %shl1 = shl i64 %b, 32
  %or = or i64 %shl1, %shl
  ret i64 %or
}

define i64 @pack_i64_2(i32 %a, i32 %b) nounwind {
; CHECK-LABEL: pack_i64_2:
; CHECK:       # %bb.0:
; CHECK-NEXT:    ret
  %zexta = zext i32 %a to i64
  %zextb = zext i32 %b to i64
  %shl1 = shl i64 %zextb, 32
  %or = or i64 %shl1, %zexta
  ret i64 %or
}

define i64 @pack_i64_3(ptr %0, ptr %1) {
; CHECK-LABEL: pack_i64_3:
; CHECK:       # %bb.0:
; CHECK-NEXT:    lw a2, 0(a0)
; CHECK-NEXT:    lw a0, 0(a1)
; CHECK-NEXT:    mv a1, a2
; CHECK-NEXT:    ret
  %3 = load i32, ptr %0, align 4
  %4 = zext i32 %3 to i64
  %5 = shl i64 %4, 32
  %6 = load i32, ptr %1, align 4
  %7 = zext i32 %6 to i64
  %8 = or i64 %5, %7
  ret i64 %8
}

define i32 @packh_i32(i32 %a, i32 %b) nounwind {
; RV32I-LABEL: packh_i32:
; RV32I:       # %bb.0:
; RV32I-NEXT:    zext.b a0, a0
; RV32I-NEXT:    slli a1, a1, 24
; RV32I-NEXT:    srli a1, a1, 16
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i32:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    packh a0, a0, a1
; RV32ZBKB-NEXT:    ret
  %and = and i32 %a, 255
  %and1 = shl i32 %b, 8
  %shl = and i32 %and1, 65280
  %or = or i32 %shl, %and
  ret i32 %or
}

define i32 @packh_i32_2(i32 %a, i32 %b) nounwind {
; RV32I-LABEL: packh_i32_2:
; RV32I:       # %bb.0:
; RV32I-NEXT:    zext.b a0, a0
; RV32I-NEXT:    zext.b a1, a1
; RV32I-NEXT:    slli a1, a1, 8
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i32_2:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    packh a0, a0, a1
; RV32ZBKB-NEXT:    ret
  %and = and i32 %a, 255
  %and1 = and i32 %b, 255
  %shl = shl i32 %and1, 8
  %or = or i32 %shl, %and
  ret i32 %or
}

define i64 @packh_i64(i64 %a, i64 %b) nounwind {
; RV32I-LABEL: packh_i64:
; RV32I:       # %bb.0:
; RV32I-NEXT:    zext.b a0, a0
; RV32I-NEXT:    slli a2, a2, 24
; RV32I-NEXT:    srli a2, a2, 16
; RV32I-NEXT:    or a0, a2, a0
; RV32I-NEXT:    li a1, 0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i64:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    packh a0, a0, a2
; RV32ZBKB-NEXT:    li a1, 0
; RV32ZBKB-NEXT:    ret
  %and = and i64 %a, 255
  %and1 = shl i64 %b, 8
  %shl = and i64 %and1, 65280
  %or = or i64 %shl, %and
  ret i64 %or
}

define i64 @packh_i64_2(i64 %a, i64 %b) nounwind {
; RV32I-LABEL: packh_i64_2:
; RV32I:       # %bb.0:
; RV32I-NEXT:    zext.b a0, a0
; RV32I-NEXT:    zext.b a1, a2
; RV32I-NEXT:    slli a1, a1, 8
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    li a1, 0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i64_2:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    packh a0, a0, a2
; RV32ZBKB-NEXT:    li a1, 0
; RV32ZBKB-NEXT:    ret
  %and = and i64 %a, 255
  %and1 = and i64 %b, 255
  %shl = shl i64 %and1, 8
  %or = or i64 %shl, %and
  ret i64 %or
}


define zeroext i16 @packh_i16(i8 zeroext %a, i8 zeroext %b) nounwind {
; RV32I-LABEL: packh_i16:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a1, a1, 8
; RV32I-NEXT:    or a0, a1, a0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i16:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    packh a0, a0, a1
; RV32ZBKB-NEXT:    ret
  %zext = zext i8 %a to i16
  %zext1 = zext i8 %b to i16
  %shl = shl i16 %zext1, 8
  %or = or i16 %shl, %zext
  ret i16 %or
}


define zeroext i16 @packh_i16_2(i8 zeroext %0, i8 zeroext %1, i8 zeroext %2) {
; RV32I-LABEL: packh_i16_2:
; RV32I:       # %bb.0:
; RV32I-NEXT:    add a0, a1, a0
; RV32I-NEXT:    slli a0, a0, 8
; RV32I-NEXT:    or a0, a0, a2
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i16_2:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    add a0, a1, a0
; RV32ZBKB-NEXT:    packh a0, a2, a0
; RV32ZBKB-NEXT:    ret
  %4 = add i8 %1, %0
  %5 = zext i8 %4 to i16
  %6 = shl i16 %5, 8
  %7 = zext i8 %2 to i16
  %8 = or i16 %6, %7
  ret i16 %8
}

define void @packh_i16_3(i8 zeroext %0, i8 zeroext %1, i8 zeroext %2, ptr %p) {
; RV32I-LABEL: packh_i16_3:
; RV32I:       # %bb.0:
; RV32I-NEXT:    add a0, a1, a0
; RV32I-NEXT:    slli a0, a0, 8
; RV32I-NEXT:    or a0, a0, a2
; RV32I-NEXT:    sh a0, 0(a3)
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: packh_i16_3:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    add a0, a1, a0
; RV32ZBKB-NEXT:    packh a0, a2, a0
; RV32ZBKB-NEXT:    sh a0, 0(a3)
; RV32ZBKB-NEXT:    ret
  %4 = add i8 %1, %0
  %5 = zext i8 %4 to i16
  %6 = shl i16 %5, 8
  %7 = zext i8 %2 to i16
  %8 = or i16 %6, %7
  store i16 %8, ptr %p
  ret void
}

define i32 @zexth_i32(i32 %a) nounwind {
; RV32I-LABEL: zexth_i32:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: zexth_i32:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    zext.h a0, a0
; RV32ZBKB-NEXT:    ret
  %and = and i32 %a, 65535
  ret i32 %and
}

define i64 @zexth_i64(i64 %a) nounwind {
; RV32I-LABEL: zexth_i64:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    li a1, 0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: zexth_i64:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    zext.h a0, a0
; RV32ZBKB-NEXT:    li a1, 0
; RV32ZBKB-NEXT:    ret
  %and = and i64 %a, 65535
  ret i64 %and
}

define i32 @zext_i16_to_i32(i16 %a) nounwind {
; RV32I-LABEL: zext_i16_to_i32:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: zext_i16_to_i32:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    zext.h a0, a0
; RV32ZBKB-NEXT:    ret
  %1 = zext i16 %a to i32
  ret i32 %1
}

define i64 @zext_i16_to_i64(i16 %a) nounwind {
; RV32I-LABEL: zext_i16_to_i64:
; RV32I:       # %bb.0:
; RV32I-NEXT:    slli a0, a0, 16
; RV32I-NEXT:    srli a0, a0, 16
; RV32I-NEXT:    li a1, 0
; RV32I-NEXT:    ret
;
; RV32ZBKB-LABEL: zext_i16_to_i64:
; RV32ZBKB:       # %bb.0:
; RV32ZBKB-NEXT:    zext.h a0, a0
; RV32ZBKB-NEXT:    li a1, 0
; RV32ZBKB-NEXT:    ret
  %1 = zext i16 %a to i64
  ret i64 %1
}

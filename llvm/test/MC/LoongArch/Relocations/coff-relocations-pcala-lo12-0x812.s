// RUN: llvm-mc -triple loongarch64-uefi -filetype obj -o %t.obj %s
// RUN: llvm-objdump -d -r %t.obj | FileCheck %s

// Test low 12-bit of the offset
    .text
main:
    la.local $t0, .Ltmp0

    .section .rdata
    .fill 2066
.Ltmp0:
    .word 1

// CHECK:      0: 4c 02 01 1a   pcalau12i    $t0, 2066
// CHECK-NEXT:          0000000000000000:  IMAGE_REL_LARCH_PCALA_HI20  .rdata
// CHECK-NEXT: 4: 8c 49 e0 02   addi.d    $t0, $t0, -2030
// CHECK-NEXT:          0000000000000004:  IMAGE_REL_LARCH_PCALA_LO12  .rdata

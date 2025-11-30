// RUN: llvm-mc -triple loongarch64-uefi -filetype obj -o %t.obj %s
// RUN: llvm-objdump -d -r %t.obj | FileCheck %s

// Test low 12-bit of the offset
    .text
main:
    la.local $t0, .Ltmp0

    .section .rdata
    .fill 2047
.Ltmp0:
    .word 1

// CHECK:      0: ec ff 00 1a   pcalau12i    $t0, 2047
// CHECK-NEXT:          0000000000000000:  IMAGE_REL_LARCH_PCALA_HI20  .rdata
// CHECK-NEXT: 4: 8c fd df 02   addi.d    $t0, $t0, 2047
// CHECK-NEXT:          0000000000000004:  IMAGE_REL_LARCH_PCALA_LO12  .rdata

// RUN: llvm-mc -triple loongarch64-unknown-uefi -filetype obj -o %t.obj %s
// RUN: llvm-objdump -d -r %t.obj | FileCheck %s
// RUN: llvm-readobj --syms %t.obj | FileCheck %s --check-prefix=SYMBOLS

    .text
main:
    la.local $t0, .Ltmp0
    la.local $t0, .Ltmp1
    la.local $t0, .Ltmp2+8

    .section .rdata
    .word 1
.Ltmp0:
    .word 2
    .fill 524288
.Ltmp1: // 512 KB + 8 bytes
    .fill (524288-8-4)
.Ltmp2: // 1 MB - 4 bytes
    .word 3
    // 1 KB here
    .word 4
    // .Ltmp2+8 points here
    .word 5

// CHECK:      0: 8c 00 00 1a   pcalau12i    $t0, 4
// CHECK-NEXT:          0000000000000000:  IMAGE_REL_LARCH_PCALA_HI20  .rdata
// CHECK-NEXT: 4: 8c 11 c0 02   addi.d    $t0, $t0, 4
// CHECK-NEXT:          0000000000000004:  IMAGE_REL_LARCH_PCALA_LO12  .rdata
// CHECK-NEXT: 8: 0c 01 00 1a   pcalau12i    $t0, 8
// CHECK-NEXT:          0000000000000008:  IMAGE_REL_LARCH_PCALA_HI20  $L.rdata_1
// CHECK-NEXT: c: 8c 21 c0 02   addi.d    $t0, $t0, 8
// CHECK-NEXT:          000000000000000c:  IMAGE_REL_LARCH_PCALA_LO12  $L.rdata_1
// CHECK-NEXT: 10: 8c 00 00 1a   pcalau12i    $t0, 4
// CHECK-NEXT:          0000000000000010:  IMAGE_REL_LARCH_PCALA_HI20  $L.rdata_2
// CHECK-NEXT: 14: 8c 11 c0 02   addi.d   $t0, $t0, 4
// CHECK-NEXT:          0000000000000014:  IMAGE_REL_LARCH_PCALA_LO12  $L.rdata_2

// SYMBOLS:      Symbol {
// SYMBOLS:        Name: $L.rdata_1
// SYMBOLS-NEXT:   Value: 524288
// SYMBOLS-NEXT:   Section: .rdata (4)
// SYMBOLS-NEXT:   BaseType: Null (0x0)
// SYMBOLS-NEXT:   ComplexType: Null (0x0)
// SYMBOLS-NEXT:   StorageClass: Label (0x6)
// SYMBOLS-NEXT:   AuxSymbolCount: 0
// SYMBOLS-NEXT: }
// SYMBOLS-NEXT: Symbol {
// SYMBOLS-NEXT:   Name: $L.rdata_2
// SYMBOLS-NEXT:   Value: 1048576
// SYMBOLS-NEXT:   Section: .rdata (4)
// SYMBOLS-NEXT:   BaseType: Null (0x0)
// SYMBOLS-NEXT:   ComplexType: Null (0x0)
// SYMBOLS-NEXT:   StorageClass: Label (0x6)
// SYMBOLS-NEXT:   AuxSymbolCount: 0
// SYMBOLS-NEXT: }

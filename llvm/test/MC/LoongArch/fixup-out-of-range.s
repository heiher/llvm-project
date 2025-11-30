// RUN: not llvm-mc -triple loongarch64 -filetype obj < %s -o /dev/null 2>&1 | FileCheck %s
// RUN: not llvm-mc -triple loongarch64-uefi -filetype obj < %s -o /dev/null 2>&1 | FileCheck %s -check-prefixes=CHECK,CHECK-WIN

// CHECK: :[[@LINE+1]]:{{[0-9]+}}: error: fixup value out of range [-134217728, 134217727]
  b distant

// CHECK: :[[@LINE+1]]:{{[0-9]+}}: error: fixup value must be 4-byte aligned
  b unaligned

// CHECK-WIN: :[[@LINE+1]]:{{[0-9]+}}: error: pcala_hi20 fixup value out of range
  pcalau12i $t0, %pc_hi20(external+0x100000)

  .byte 0
unaligned:
  .byte 0

  .space 1<<27
  .balign 8
distant:
  .word 0

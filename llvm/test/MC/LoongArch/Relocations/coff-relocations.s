// RUN: llvm-mc -triple loongarch64-uefi -filetype obj -o %t.obj %s
// RUN: llvm-readobj -r %t.obj | FileCheck %s --check-prefixes=CHECK,CHECK-LA64
// RUN: llvm-objdump --no-print-imm-hex -d %t.obj | FileCheck %s --check-prefix=DISASM
// RUN: llvm-objdump -s %t.obj | FileCheck %s --check-prefix=DATA

# RUN: not llvm-mc -triple=loongarch64-uefi -filetype=obj %s --defsym ERR=1 -o /dev/null 2>&1 | FileCheck %s --check-prefix=ERR --implicit-check-not=error:

// IMAGE_REL_LARCH_ADDR32
.Linfo_foo:
  .asciz "foo"
  .long foo

// IMAGE_REL_LARCH_ADDR32NB
.long func@IMGREL

// IMAGE_REL_LARCH_ADDR64
.globl struc
struc:
  .quad arr

// IMAGE_REL_LARCH_BRANCH26
b target

// IMAGE_REL_LARCH_BRANCH21
beqz $t0, target21

// IMAGE_REL_LARCH_ADDR_HI20
lu12i.w $t1, %abs_hi20(symbol_hi20)

// IMAGE_REL_LARCH_ADDR_LO12
ori $t1, $t1, %abs_lo12(symbol_lo12)

// IMAGE_REL_LARCH_ADDR64_LO20
lu32i.d $t2, %abs64_lo20(symbol64_lo20)

// IMAGE_REL_LARCH_ADDR64_HI12
lu52i.d $t2, $t2, %abs64_hi12(symbol64_hi12)

// IMAGE_REL_LARCH_PCALA_HI20
pcalau12i $t0, %pc_hi20(foo)

// IMAGE_REL_LARCH_PCALA_LO12
addi.d $t0, $t0, %pc_lo12(foo)

// IMAGE_REL_LARCH_PCALA_HI20, even if the symbol offset is known
pcalau12i $t0, %pc_hi20(bar)
bar:

// IMAGE_REL_LARCH_SECREL
.secrel32 .Linfo_bar
.Linfo_bar:

// IMAGE_REL_LARCH_SECTION
.secidx func

.align 2
pcalau12i $t0, %pc_hi20(baz + 0x12345)
baz:

// IMAGE_REL_LARCH_BRANCH16
bne $t1, $t2, %b16(target)

.section .rdata, "dr"
.Ltable:
.word .Linfo_bar - .Ltable
.word .Linfo_foo - .Ltable

// As an extension, we allow 64-bit label differences. They lower to
// IMAGE_REL_LARCH_REL32 because IMAGE_REL_LARCH_REL64 does not exist.
.dword .Linfo_foo - .Ltable

// CHECK: Format: COFF-loongarch64
// CHECK-LA64: Arch: loongarch64
// CHECK: AddressSize: 64bit
// CHECK: Relocations [
// CHECK:   Section (1) .text {
// CHECK: 0x4 IMAGE_REL_LARCH_ADDR32 foo
// CHECK: 0x8 IMAGE_REL_LARCH_ADDR32NB func
// CHECK: 0xC IMAGE_REL_LARCH_ADDR64 arr
// CHECK: 0x14 IMAGE_REL_LARCH_BRANCH26 target
// CHECK: 0x18 IMAGE_REL_LARCH_BRANCH21 target21
// CHECK: 0x1C IMAGE_REL_LARCH_ADDR_HI20 symbol_hi20
// CHECK: 0x20 IMAGE_REL_LARCH_ADDR_LO12 symbol_lo12
// CHECK: 0x24 IMAGE_REL_LARCH_ADDR64_LO20 symbol64_lo20
// CHECK: 0x28 IMAGE_REL_LARCH_ADDR64_HI12 symbol64_hi12
// CHECK: 0x2C IMAGE_REL_LARCH_PCALA_HI20 foo
// CHECK: 0x30 IMAGE_REL_LARCH_PCALA_LO12 foo
// CHECK: 0x34 IMAGE_REL_LARCH_PCALA_HI20 bar
// CHECK: 0x38 IMAGE_REL_LARCH_SECREL .text
// CHECK: 0x3C IMAGE_REL_LARCH_SECTION func
// CHECK: 0x40 IMAGE_REL_LARCH_PCALA_HI20 baz
// CHECK: 0x44 IMAGE_REL_LARCH_BRANCH16 target
// CHECK:   }
// CHECK:   Section (4) .rdata {
// CHECK: 0x0 IMAGE_REL_LARCH_REL32 .text
// CHECK: 0x4 IMAGE_REL_LARCH_REL32 .text
// CHECK: 0x8 IMAGE_REL_LARCH_REL32 .text
// CHECK:   }
// CHECK: ]

// DISASM:  34: 0c 00 00 1a     pcalau12i    $t0, 0

// DATA: Contents of section .rdata:
// DATA-NEXT:  0000 40000000 08000000

.ifdef ERR
# ERR: [[#@LINE+1]]:12: error: invalid variant 'plt'
.long func@plt
.endif

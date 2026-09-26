# REQUIRES: loongarch
##
## call36 -> bl relaxation (relaxMediumCall, isInt<28>) must not
## oscillate between remove=0 and remove=4. Without the fix, ld.lld reports
## "address assignment did not converge".
##
## Unlike RISC-V calls (8 -> 4 -> 2 bytes), every LoongArch medium call site has
## only two states (8 or 4 bytes), so oscillation is always a 0 <-> 4 flip.
## The flip needs a site whose distance sits exactly at the +-128MiB limit while
## a ".p2align 4" (R_LARCH_ALIGN) absorbs some shrinks but not others, so the
## target address jitters between passes.
##
## The layout is deliberately fragile: the .space size below was found by
## searching a model of lld's relaxation loop. Do not "round" it.

# RUN: llvm-mc -filetype=obj -triple=loongarch64 -mattr=+relax %s -o %t.o
# RUN: ld.lld -e _start %t.o -o %t
# RUN: llvm-objdump -d --no-show-raw-insn %t | FileCheck %s

## The two short-range sites in .text.a are always relaxed.
# CHECK-LABEL: <_start>:
# CHECK-NEXT:    bl
# CHECK-NEXT:    bl

.section .text.a,"ax"
.globl _start
_start:
  call36 t_d
  call36 t_e
  call36 t_c            # forward, crosses the 128MiB filler
.globl t_d
t_d:
.globl t_e
t_e:

.section .text.b,"ax"
  .space 8
  call36 t_a
  call36 t_d            # backward, crosses the 128MiB filler
  .space 134217696 # 128MiB - 32: puts the sites right at the isInt<28> limit
  call36 _start         # backward, near the limit
.globl t_c
t_c:
  .p2align 4        # R_LARCH_ALIGN; also makes .text.b 16-byte aligned
  call36 t_d
.globl t_a
t_a:

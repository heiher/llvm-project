# REQUIRES: aarch64

## Check for the following:
## (1) address match between thunk definitions and call destinations
## (2) address match between thunk page+offset computations and function
##     definitions
## (3) a second thunk is created when the first one goes out of range
## (4) early calls to a dylib stub use a thunk, and later calls the stub
##     directly
## (5) Thunks are created for all sections in the text segment with branches.
## (6) Thunks are in the linker map file.
## Notes:
## 0x4000000 = 64 Mi = half the magnitude of the forward-branch range

# RUN: rm -rf %t; mkdir %t
# RUN: llvm-mc -filetype=obj -triple=arm64-apple-darwin %s -o %t/input.o
## Use --icf=safe_thunks to test that branch extension algo is compatible
## with safe_thunks ICF.
# RUN: %lld -arch arm64 -dead_strip -lSystem -U _extern_sym -map %t/thunk.map -o %t/thunk %t/input.o --icf=safe_thunks
# RUN: llvm-objdump --no-print-imm-hex -d --no-show-raw-insn %t/thunk | FileCheck %s
# RUN: llvm-objdump --macho --section-headers %t/thunk > %t/headers.txt
# RUN: llvm-otool -vs __DATA __objc_selrefs %t/thunk >> %t/headers.txt
# RUN: llvm-otool -vs __TEXT __objc_stubs %t/thunk >> %t/headers.txt
# RUN: FileCheck %s --check-prefix=OBJC < %t/headers.txt

# RUN: FileCheck %s --input-file %t/thunk.map --check-prefix=MAP

# OBJC: Sections:
# OBJC: __text
# OBJC-NEXT: __lcxx_override
# OBJC-NEXT: __stubs
# OBJC-NEXT: __stub_helper
# OBJC-NEXT: __objc_stubs

# OBJC: Contents of (__DATA,__objc_selrefs) section
# OBJC-NEXT: {{[0-9a-f]*}}  __TEXT:__objc_methname:foo
# OBJC-NEXT: {{[0-9a-f]*}}  __TEXT:__objc_methname:bar

# OBJC: Contents of (__TEXT,__objc_stubs) section
# OBJC: _objc_msgSend$bar:
# OBJC: _objc_msgSend$foo:

# MAP:      0x{{[[:xdigit:]]+}} {{.*}} _fold_func_low_addr
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _a
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _b
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _c
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _d.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _e.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _f.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _g.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _h.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} ___nan.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _d
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _e
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _f
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _g
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _a.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _b.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _h
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _main
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _fold_func_high_addr
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _c.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _d.thunk.1
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _e.thunk.1
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _f.thunk.1
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _fold_func_low_addr.thunk.0
# MAP-NEXT: 0x{{[[:xdigit:]]+}} {{.*}} _z


# CHECK: Disassembly of section __TEXT,__text:

# CHECK: [[#%.13x, A_PAGE:]][[#%.3x, A_OFFSET:]] <_a>:
# CHECK:  bl 0x[[#%x, A:]] <_a>
# CHECK:  bl 0x[[#%x, B:]] <_b>
# CHECK:  bl 0x[[#%x, C:]] <_c>
# CHECK:  bl 0x[[#%x, D_THUNK_0:]] <_d.thunk.0>
# CHECK:  bl 0x[[#%x, E_THUNK_0:]] <_e.thunk.0>
# CHECK:  bl 0x[[#%x, F_THUNK_0:]] <_f.thunk.0>
# CHECK:  bl 0x[[#%x, G_THUNK_0:]] <_g.thunk.0>
# CHECK:  bl 0x[[#%x, H_THUNK_0:]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0:]] <___nan.thunk.0>

# CHECK: [[#%.13x, B_PAGE:]][[#%.3x, B_OFFSET:]] <_b>:
# CHECK:  bl 0x[[#%x, A]] <_a>
# CHECK:  bl 0x[[#%x, B]] <_b>
# CHECK:  bl 0x[[#%x, C]] <_c>
# CHECK:  bl 0x[[#%x, D_THUNK_0]] <_d.thunk.0>
# CHECK:  bl 0x[[#%x, E_THUNK_0]] <_e.thunk.0>
# CHECK:  bl 0x[[#%x, F_THUNK_0]] <_f.thunk.0>
# CHECK:  bl 0x[[#%x, G_THUNK_0]] <_g.thunk.0>
# CHECK:  bl 0x[[#%x, H_THUNK_0]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0]] <___nan.thunk.0>

# CHECK: [[#%.13x, C_PAGE:]][[#%.3x, C_OFFSET:]] <_c>:
# CHECK:  bl 0x[[#%x, A]] <_a>
# CHECK:  bl 0x[[#%x, B]] <_b>
# CHECK:  bl 0x[[#%x, C]] <_c>
# CHECK:  bl 0x[[#%x, D:]] <_d>
# CHECK:  bl 0x[[#%x, E:]] <_e>
# CHECK:  bl 0x[[#%x, F_THUNK_0]] <_f.thunk.0>
# CHECK:  bl 0x[[#%x, G_THUNK_0]] <_g.thunk.0>
# CHECK:  bl 0x[[#%x, H_THUNK_0]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0]] <___nan.thunk.0>

# CHECK: [[#%x, D_THUNK_0]] <_d.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, D_PAGE:]]
# CHECK:  add  x16, x16, #[[#D_OFFSET:]]

# CHECK: [[#%x, E_THUNK_0]] <_e.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, E_PAGE:]]
# CHECK:  add  x16, x16, #[[#E_OFFSET:]]

# CHECK: [[#%x, F_THUNK_0]] <_f.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, F_PAGE:]]
# CHECK:  add  x16, x16, #[[#F_OFFSET:]]

# CHECK: [[#%x, G_THUNK_0]] <_g.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, G_PAGE:]]
# CHECK:  add  x16, x16, #[[#G_OFFSET:]]

# CHECK: [[#%x, H_THUNK_0]] <_h.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, H_PAGE:]]
# CHECK:  add  x16, x16, #[[#H_OFFSET:]]

# CHECK: [[#%x, NAN_THUNK_0]] <___nan.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, NAN_PAGE:]]
# CHECK:  add  x16, x16, #[[#NAN_OFFSET:]]

# CHECK: [[#%x, D_PAGE + D_OFFSET]] <_d>:
# CHECK:  bl 0x[[#%x, A]] <_a>
# CHECK:  bl 0x[[#%x, B]] <_b>
# CHECK:  bl 0x[[#%x, C]] <_c>
# CHECK:  bl 0x[[#%x, D]] <_d>
# CHECK:  bl 0x[[#%x, E]] <_e>
# CHECK:  bl 0x[[#%x, F_THUNK_0]] <_f.thunk.0>
# CHECK:  bl 0x[[#%x, G_THUNK_0]] <_g.thunk.0>
# CHECK:  bl 0x[[#%x, H_THUNK_0]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0]] <___nan.thunk.0>

# CHECK: [[#%x, E_PAGE + E_OFFSET]] <_e>:
# CHECK:  bl 0x[[#%x, A_THUNK_0:]] <_a.thunk.0>
# CHECK:  bl 0x[[#%x, B_THUNK_0:]] <_b.thunk.0>
# CHECK:  bl 0x[[#%x, C]] <_c>
# CHECK:  bl 0x[[#%x, D]] <_d>
# CHECK:  bl 0x[[#%x, E]] <_e>
# CHECK:  bl 0x[[#%x, F:]] <_f>
# CHECK:  bl 0x[[#%x, G:]] <_g>
# CHECK:  bl 0x[[#%x, H_THUNK_0]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0]] <___nan.thunk.0>

# CHECK: [[#%x, F_PAGE + F_OFFSET]] <_f>:
# CHECK:  bl 0x[[#%x, A_THUNK_0]] <_a.thunk.0>
# CHECK:  bl 0x[[#%x, B_THUNK_0]] <_b.thunk.0>
# CHECK:  bl 0x[[#%x, C]] <_c>
# CHECK:  bl 0x[[#%x, D]] <_d>
# CHECK:  bl 0x[[#%x, E]] <_e>
# CHECK:  bl 0x[[#%x, F]] <_f>
# CHECK:  bl 0x[[#%x, G]] <_g>
# CHECK:  bl 0x[[#%x, H_THUNK_0]] <_h.thunk.0>
# CHECK:  bl 0x[[#%x, NAN_THUNK_0]] <___nan.thunk.0>

# CHECK: [[#%x, G_PAGE + G_OFFSET]] <_g>:
# CHECK:  bl 0x[[#%x, A_THUNK_0]] <_a.thunk.0>
# CHECK:  bl 0x[[#%x, B_THUNK_0]] <_b.thunk.0>
# CHECK:  bl 0x[[#%x, C_THUNK_0:]] <_c.thunk.0>
# CHECK:  bl 0x[[#%x, D_THUNK_1:]] <_d.thunk.1>
# CHECK:  bl 0x[[#%x, E]] <_e>
# CHECK:  bl 0x[[#%x, F]] <_f>
# CHECK:  bl 0x[[#%x, G]] <_g>
# CHECK:  bl 0x[[#%x, H:]] <_h>
# CHECK:  bl 0x[[#%x, STUBS:]]

# CHECK: [[#%x, A_THUNK_0]] <_a.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, A_PAGE]]000
# CHECK:  add  x16, x16, #[[#%d, A_OFFSET]]

# CHECK: [[#%x, B_THUNK_0]] <_b.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, B_PAGE]]000
# CHECK:  add  x16, x16, #[[#%d, B_OFFSET]]

# CHECK: [[#%x, H_PAGE + H_OFFSET]] <_h>:
# CHECK:  bl 0x[[#%x, A_THUNK_0]] <_a.thunk.0>
# CHECK:  bl 0x[[#%x, B_THUNK_0]] <_b.thunk.0>
# CHECK:  bl 0x[[#%x, C_THUNK_0]] <_c.thunk.0>
# CHECK:  bl 0x[[#%x, D_THUNK_1]] <_d.thunk.1>
# CHECK:  bl 0x[[#%x, E]] <_e>
# CHECK:  bl 0x[[#%x, F]] <_f>
# CHECK:  bl 0x[[#%x, G]] <_g>
# CHECK:  bl 0x[[#%x, H]] <_h>
# CHECK:  bl 0x[[#%x, STUBS]]

# CHECK: <_main>:
# CHECK:  bl 0x[[#%x, A_THUNK_0]] <_a.thunk.0>
# CHECK:  bl 0x[[#%x, B_THUNK_0]] <_b.thunk.0>
# CHECK:  bl 0x[[#%x, C_THUNK_0]] <_c.thunk.0>
# CHECK:  bl 0x[[#%x, D_THUNK_1]] <_d.thunk.1>
# CHECK:  bl 0x[[#%x, E_THUNK_1:]] <_e.thunk.1>
# CHECK:  bl 0x[[#%x, F_THUNK_1:]] <_f.thunk.1>
# CHECK:  bl 0x[[#%x, G]] <_g>
# CHECK:  bl 0x[[#%x, H]] <_h>
# CHECK:  bl 0x[[#%x, STUBS]]

# CHECK: [[#%x, C_THUNK_0]] <_c.thunk.0>:
# CHECK:  adrp x16, 0x[[#%x, C_PAGE]]000
# CHECK:  add  x16, x16, #[[#%d, C_OFFSET]]

# CHECK: [[#%x, D_THUNK_1]] <_d.thunk.1>:
# CHECK:  adrp x16, 0x[[#%x, D_PAGE]]
# CHECK:  add  x16, x16, #[[#D_OFFSET]]

# CHECK: [[#%x, E_THUNK_1]] <_e.thunk.1>:
# CHECK:  adrp x16, 0x[[#%x, E_PAGE]]
# CHECK:  add  x16, x16, #[[#E_OFFSET]]

# CHECK: [[#%x, F_THUNK_1]] <_f.thunk.1>:
# CHECK:  adrp x16, 0x[[#%x, F_PAGE]]
# CHECK:  add  x16, x16, #[[#F_OFFSET]]

# CHECK: Disassembly of section __TEXT,__lcxx_override:
# CHECK: <_z>:
# CHECK:  bl 0x[[#%x, A_THUNK_0]] <_a.thunk.0>

# CHECK: Disassembly of section __TEXT,__stubs:

# CHECK: [[#%x, NAN_PAGE + NAN_OFFSET]] <__stubs>:

.section  __TEXT,__objc_methname,cstring_literals
lselref1:
  .asciz  "foo"
lselref2:
  .asciz  "bar"

.section  __DATA,__objc_selrefs,literal_pointers,no_dead_strip
.p2align  3
.quad lselref1
.quad lselref2

.text
.globl _objc_msgSend
_objc_msgSend:
  ret

.subsections_via_symbols

.addrsig
.addrsig_sym _fold_func_low_addr
.addrsig_sym _fold_func_high_addr

.text

.globl _fold_func_low_addr
.p2align 2
_fold_func_low_addr:
  add x0, x0, x0
  add x1, x0, x1
  add x2, x0, x2
  ret

.globl _a
.p2align 2
_a:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  ret

.globl _b
.p2align 2
_b:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  .space 0x4000000-0x3c
  ret

.globl _c
.p2align 2
_c:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  ret

.globl _d
.p2align 2
_d:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  .space 0x4000000-0x38
  ret

.globl _e
.p2align 2
_e:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  ret

.globl _f
.p2align 2
_f:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  .space 0x4000000-0x34
  ret

.globl _g
.p2align 2
_g:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  ret

.globl _h
.p2align 2
_h:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl ___nan
  .space 0x4000000-0x30
  ret

.globl _main
.p2align 2
_main:
  bl _a
  bl _b
  bl _c
  bl _d
  bl _e
  bl _f
  bl _g
  bl _h
  bl _fold_func_low_addr
  bl _fold_func_high_addr
  bl ___nan
  bl _objc_msgSend$foo
  bl _objc_msgSend$bar
  ret

.globl _fold_func_high_addr
.p2align 2
_fold_func_high_addr:
  add x0, x0, x0
  add x1, x0, x1
  add x2, x0, x2
  ret


.section __TEXT,__cstring
  # The .space below has to be composed of non-zero characters. Otherwise, the
  # linker will create a symbol for every '0' in the section, leading to
  # dramatic memory usage and a huge linker map file
  .space 0x4000000, 'A'
  .byte 0


.section __TEXT,__lcxx_override,regular,pure_instructions

.globl _z
.no_dead_strip _z
.p2align 2
_z:
  bl _a
  ## Ensure calling into stubs works
  bl _extern_sym
  ret

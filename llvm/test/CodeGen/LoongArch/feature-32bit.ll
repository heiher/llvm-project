; RUN: llc --mtriple=loongarch64 --mattr=help 2>&1 | FileCheck %s
; RUN: llc --mtriple=loongarch32 --mattr=help 2>&1 | FileCheck %s

; CHECK: Available features for this target:
; CHECK: la32r - LA32 Reduced Basic Integer and Privilege Instruction Set.
; CHECK: la32s - LA32 Standard Basic Integer and Privilege Instruction Set.

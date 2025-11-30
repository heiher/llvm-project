; RUN: llc -mtriple loongarch64-uefi -filetype=obj -code-model=small < %s | obj2yaml | FileCheck %s

; CHECK:  Machine:         IMAGE_FILE_MACHINE_LOONGARCH64

; CHECK:  - Name:            .text
; CHECK:    Relocations:

declare void @bar()
define i32 @foo_jmp() {
  call i32 @bar()
; CHECK:      - VirtualAddress:  8
; CHECK:        SymbolName:      bar
; CHECK:        Type:            IMAGE_REL_LARCH_B26
  ret i32 0
}

; CHECK:  - Name:            .data
; CHECK:    Relocations:

%struct._PTR = type { ptr }

@var1 = internal global %struct._PTR { ptr @var2 }
@var2 = external global i32
; CHECK:      - VirtualAddress:  0
; CHECK:        SymbolName:      var2

; CHECK:  - Name:            '.debug$S'
; CHECK:    Relocations:

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4}

!0 = distinct !DICompileUnit(language: DW_LANG_C11, file: !1, emissionKind: FullDebug)
!1 = !DIFile(filename: "dummy.c", directory: "/tmp/private")
!2 = !{i32 2, !"CodeView", i32 1}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 2}
!5 = distinct !DISubprogram(name: "foo", scope: !1, file: !1, line: 1, type: !6, scopeLine: 2, spFlags: DISPFlagDefinition, unit: !0)
!6 = !DISubroutineType(types: !7)
!7 = !{null}
!8 = !DILocation(line: 3, scope: !5)

define dso_local void @foo_dbg() #0 !dbg !5 {
  ret void, !dbg !8
; CHECK:      - VirtualAddress:  92
; CHECK:        SymbolName:      foo_dbg
; CHECK:        Type:            IMAGE_REL_LARCH_SECREL
; CHECK:      - VirtualAddress:  96
; CHECK:        SymbolName:      foo_dbg
; CHECK:        Type:            IMAGE_REL_LARCH_SECTION
; CHECK:      - VirtualAddress:  148
; CHECK:        SymbolName:      foo_dbg
; CHECK:        Type:            IMAGE_REL_LARCH_SECREL
; CHECK:      - VirtualAddress:  152
; CHECK:        SymbolName:      foo_dbg
; CHECK:        Type:            IMAGE_REL_LARCH_SECTION
}


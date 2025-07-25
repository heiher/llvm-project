; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=x86_64-- -disable-cgp-delete-phis | FileCheck %s

	%struct.COMPOSITE = type { i8, i16, i16 }
	%struct.FILE = type { ptr, i32, i32, i16, i16, %struct.__sbuf, i32, ptr, ptr, ptr, ptr, ptr, %struct.__sbuf, ptr, i32, [3 x i8], [1 x i8], %struct.__sbuf, i32, i64 }
	%struct.FILE_POS = type { i8, i8, i16, i32 }
	%struct.FIRST_UNION = type { %struct.FILE_POS }
	%struct.FONT_INFO = type { ptr, ptr, ptr, ptr, i32, ptr, ptr, i16, i16, ptr, ptr, ptr, ptr }
	%struct.FOURTH_UNION = type { %struct.STYLE }
	%struct.GAP = type { i8, i8, i16 }
	%struct.LIST = type { ptr, ptr }
	%struct.SECOND_UNION = type { { i16, i8, i8 } }
	%struct.STYLE = type { { %struct.GAP }, { %struct.GAP }, i16, i16, i32 }
	%struct.THIRD_UNION = type { ptr, [8 x i8] }
	%struct.__sFILEX = type opaque
	%struct.__sbuf = type { ptr, i32 }
	%struct.head_type = type { [2 x %struct.LIST], %struct.FIRST_UNION, %struct.SECOND_UNION, %struct.THIRD_UNION, %struct.FOURTH_UNION, ptr, { ptr }, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i32 }
	%struct.metrics = type { i16, i16, i16, i16, i16 }
	%struct.rec = type { %struct.head_type }

define void @FontChange(i1 %foo) nounwind {
; CHECK-LABEL: FontChange:
; CHECK:       # %bb.0: # %entry
; CHECK-NEXT:    testb $1, %dil
; CHECK-NEXT:    je .LBB0_10
; CHECK-NEXT:    .p2align 4
; CHECK-NEXT:  .LBB0_1: # %bb366
; CHECK-NEXT:    # =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    testb $1, %dil
; CHECK-NEXT:    jne .LBB0_1
; CHECK-NEXT:  # %bb.2: # %bb428
; CHECK-NEXT:    testb $1, %dil
; CHECK-NEXT:    je .LBB0_10
; CHECK-NEXT:  # %bb.3:
; CHECK-NEXT:    cmpb $0, 0
; CHECK-NEXT:    .p2align 4
; CHECK-NEXT:  .LBB0_4: # %bb650
; CHECK-NEXT:    # =>This Inner Loop Header: Depth=1
; CHECK-NEXT:    je .LBB0_4
; CHECK-NEXT:  # %bb.5: # %bb662
; CHECK-NEXT:    movl 0, %eax
; CHECK-NEXT:    movl %eax, %ecx
; CHECK-NEXT:    andl $57344, %ecx # imm = 0xE000
; CHECK-NEXT:    cmpl $8192, %ecx # imm = 0x2000
; CHECK-NEXT:    jne .LBB0_10
; CHECK-NEXT:  # %bb.6: # %bb4884
; CHECK-NEXT:    andl $7168, %eax # imm = 0x1C00
; CHECK-NEXT:    cmpl $1024, %eax # imm = 0x400
; CHECK-NEXT:    jne .LBB0_10
; CHECK-NEXT:  # %bb.7: # %bb4932
; CHECK-NEXT:    testb $1, %dil
; CHECK-NEXT:    jne .LBB0_10
; CHECK-NEXT:  # %bb.8: # %bb4940
; CHECK-NEXT:    movl 0, %eax
; CHECK-NEXT:    cmpl $160, %eax
; CHECK-NEXT:    je .LBB0_10
; CHECK-NEXT:  # %bb.9: # %bb4940
; CHECK-NEXT:    cmpl $159, %eax
; CHECK-NEXT:  .LBB0_10: # %bb4897
; CHECK-NEXT:    retq
entry:
	br i1 %foo, label %bb298, label %bb49
bb49:		; preds = %entry
	ret void
bb298:		; preds = %entry
	br i1 %foo, label %bb304, label %bb366
bb304:		; preds = %bb298
	br i1 %foo, label %bb330, label %bb428
bb330:		; preds = %bb366, %bb304
	br label %bb366
bb366:		; preds = %bb330, %bb298
	br i1 %foo, label %bb330, label %bb428
bb428:		; preds = %bb366, %bb304
	br i1 %foo, label %bb650, label %bb433
bb433:		; preds = %bb428
	ret void
bb650:		; preds = %bb650, %bb428
	%tmp658 = load i8, ptr null, align 8		; <i8> [#uses=1]
	%tmp659 = icmp eq i8 %tmp658, 0		; <i1> [#uses=1]
	br i1 %tmp659, label %bb650, label %bb662
bb662:		; preds = %bb650
	br label %bb761
bb688:		; preds = %bb662
	ret void
bb761:		; preds = %bb662
	%tmp487248736542 = load i32, ptr null, align 4		; <i32> [#uses=2]
	%tmp487648776541 = and i32 %tmp487248736542, 57344		; <i32> [#uses=1]
	%tmp4881 = icmp eq i32 %tmp487648776541, 8192		; <i1> [#uses=1]
	br i1 %tmp4881, label %bb4884, label %bb4897
bb4884:		; preds = %bb761
	%tmp488948906540 = and i32 %tmp487248736542, 7168		; <i32> [#uses=1]
	%tmp4894 = icmp eq i32 %tmp488948906540, 1024		; <i1> [#uses=1]
	br i1 %tmp4894, label %bb4932, label %bb4897
bb4897:		; preds = %bb4884, %bb761
	ret void
bb4932:		; preds = %bb4884
	%tmp4933 = load i32, ptr null, align 4		; <i32> [#uses=1]
	br i1 %foo, label %bb5054, label %bb4940
bb4940:		; preds = %bb4932
	%tmp4943 = load i32, ptr null, align 4		; <i32> [#uses=2]
	switch i32 %tmp4933, label %bb5054 [
		 i32 159, label %bb4970
		 i32 160, label %bb5002
	]
bb4970:		; preds = %bb4940
	%tmp49746536 = trunc i32 %tmp4943 to i16		; <i16> [#uses=1]
	%tmp49764977 = and i16 %tmp49746536, 4095		; <i16> [#uses=1]
	%mask498049814982 = zext i16 %tmp49764977 to i64		; <i64> [#uses=1]
	%tmp4984 = getelementptr %struct.FONT_INFO, ptr null, i64 %mask498049814982, i32 5		; <ptr> [#uses=1]
	%tmp4985 = load ptr, ptr %tmp4984, align 8		; <ptr> [#uses=1]
	%tmp4988 = getelementptr %struct.rec, ptr %tmp4985, i64 0, i32 0, i32 3		; <ptr> [#uses=1]
	%tmp4992 = load i32, ptr %tmp4988, align 8		; <i32> [#uses=1]
	%tmp49924993 = trunc i32 %tmp4992 to i16		; <i16> [#uses=1]
	%tmp4996 = add i16 %tmp49924993, 0		; <i16> [#uses=1]
	br label %bb5054
bb5002:		; preds = %bb4940
	%tmp50066537 = trunc i32 %tmp4943 to i16		; <i16> [#uses=1]
	%tmp50085009 = and i16 %tmp50066537, 4095		; <i16> [#uses=1]
	%mask501250135014 = zext i16 %tmp50085009 to i64		; <i64> [#uses=1]
	%tmp5016 = getelementptr %struct.FONT_INFO, ptr null, i64 %mask501250135014, i32 5		; <ptr> [#uses=1]
	%tmp5017 = load ptr, ptr %tmp5016, align 8		; <ptr> [#uses=1]
	%tmp5020 = getelementptr %struct.rec, ptr %tmp5017, i64 0, i32 0, i32 3		; <ptr> [#uses=1]
	%tmp5024 = load i32, ptr %tmp5020, align 8		; <i32> [#uses=1]
	%tmp50245025 = trunc i32 %tmp5024 to i16		; <i16> [#uses=1]
	%tmp5028 = sub i16 %tmp50245025, 0		; <i16> [#uses=1]
	br label %bb5054
bb5054:		; preds = %bb5002, %bb4970, %bb4940, %bb4932
	%flen.0.reg2mem.0 = phi i16 [ %tmp4996, %bb4970 ], [ %tmp5028, %bb5002 ], [ 0, %bb4932 ], [ undef, %bb4940 ]		; <i16> [#uses=0]
	ret void
}

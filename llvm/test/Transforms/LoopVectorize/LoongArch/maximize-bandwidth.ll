; RUN: opt -passes=loop-vectorize -mtriple=loongarch64 -mattr=+lsx \
; RUN:   -pass-remarks=loop-vectorize -disable-output < %s 2>&1 | FileCheck %s
; RUN: opt -passes=loop-vectorize -mtriple=loongarch64 -mattr=+lasx \
; RUN:   -pass-remarks=loop-vectorize -disable-output < %s 2>&1 | FileCheck %s --check-prefix=LASX

;; Count the bytes equal to '<' into a 64-bit accumulator, as Rust
;; `bytes().filter(|c| *c == b'<').count()` does.
define i64 @count_eq_i64(ptr %p, i64 %n) {
; CHECK: remark: <unknown>:0:0: vectorized loop (vectorization width: 2, interleaved count: 2)
; LASX: remark: <unknown>:0:0: vectorized loop (vectorization width: 4, interleaved count: 2)
entry:
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi i64 [ 0, %entry ], [ %acc.next, %loop ]
  %gep = getelementptr inbounds i8, ptr %p, i64 %i
  %c = load i8, ptr %gep, align 1
  %eq = icmp eq i8 %c, 60
  %z = zext i1 %eq to i64
  %acc.next = add i64 %acc, %z
  %i.next = add nuw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret i64 %acc.next
}

;; Count the newlines into a 32-bit accumulator.
define i32 @count_eq_i32(ptr %p, i64 %n) {
; CHECK: remark: <unknown>:0:0: vectorized loop (vectorization width: 4, interleaved count: 2)
; LASX: remark: <unknown>:0:0: vectorized loop (vectorization width: 8, interleaved count: 2)
entry:
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %acc = phi i32 [ 0, %entry ], [ %acc.next, %loop ]
  %gep = getelementptr inbounds i8, ptr %p, i64 %i
  %c = load i8, ptr %gep, align 1
  %eq = icmp eq i8 %c, 10
  %z = zext i1 %eq to i32
  %acc.next = add i32 %acc, %z
  %i.next = add nuw i64 %i, 1
  %done = icmp eq i64 %i.next, %n
  br i1 %done, label %exit, label %loop

exit:
  ret i32 %acc.next
}

;; Accumulate 9 products of i16 taps into 64-bit accumulators, as GSM
;; Autocorrelation does. Wide VFs need more vector registers than available.
define void @autocorrelation(ptr %s, ptr %L) {
; CHECK: remark: <unknown>:0:0: vectorized loop (vectorization width: 2, interleaved count: 2)
; LASX: remark: <unknown>:0:0: vectorized loop (vectorization width: 4, interleaved count: 2)
entry:
  %s.start = getelementptr inbounds nuw i8, ptr %s, i64 14
  %first = load i16, ptr %s.start, align 2
  br label %loop

loop:
  %prev = phi i16 [ %first, %entry ], [ %cur, %loop ]
  %i = phi i32 [ 8, %entry ], [ %i.next, %loop ]
  %sp = phi ptr [ %s.start, %entry ], [ %sp.next, %loop ]
  %a0 = phi i64 [ 0, %entry ], [ %a0.next, %loop ]
  %a1 = phi i64 [ 0, %entry ], [ %a1.next, %loop ]
  %a2 = phi i64 [ 0, %entry ], [ %a2.next, %loop ]
  %a3 = phi i64 [ 0, %entry ], [ %a3.next, %loop ]
  %a4 = phi i64 [ 0, %entry ], [ %a4.next, %loop ]
  %a5 = phi i64 [ 0, %entry ], [ %a5.next, %loop ]
  %a6 = phi i64 [ 0, %entry ], [ %a6.next, %loop ]
  %a7 = phi i64 [ 0, %entry ], [ %a7.next, %loop ]
  %a8 = phi i64 [ 0, %entry ], [ %a8.next, %loop ]
  %sp.next = getelementptr inbounds nuw i8, ptr %sp, i64 2
  %cur = load i16, ptr %sp.next, align 2
  %x = sext i16 %cur to i64
  %m0 = mul nsw i64 %x, %x
  %a0.next = add nsw i64 %m0, %a0
  %y1 = sext i16 %prev to i64
  %m1 = mul nsw i64 %x, %y1
  %a1.next = add nsw i64 %m1, %a1
  %p2 = getelementptr inbounds i8, ptr %sp, i64 -2
  %l2 = load i16, ptr %p2, align 2
  %y2 = sext i16 %l2 to i64
  %m2 = mul nsw i64 %y2, %x
  %a2.next = add nsw i64 %m2, %a2
  %p3 = getelementptr inbounds i8, ptr %sp, i64 -4
  %l3 = load i16, ptr %p3, align 2
  %y3 = sext i16 %l3 to i64
  %m3 = mul nsw i64 %y3, %x
  %a3.next = add nsw i64 %m3, %a3
  %p4 = getelementptr inbounds i8, ptr %sp, i64 -6
  %l4 = load i16, ptr %p4, align 2
  %y4 = sext i16 %l4 to i64
  %m4 = mul nsw i64 %y4, %x
  %a4.next = add nsw i64 %m4, %a4
  %p5 = getelementptr inbounds i8, ptr %sp, i64 -8
  %l5 = load i16, ptr %p5, align 2
  %y5 = sext i16 %l5 to i64
  %m5 = mul nsw i64 %y5, %x
  %a5.next = add nsw i64 %m5, %a5
  %p6 = getelementptr inbounds i8, ptr %sp, i64 -10
  %l6 = load i16, ptr %p6, align 2
  %y6 = sext i16 %l6 to i64
  %m6 = mul nsw i64 %y6, %x
  %a6.next = add nsw i64 %m6, %a6
  %p7 = getelementptr inbounds i8, ptr %sp, i64 -12
  %l7 = load i16, ptr %p7, align 2
  %y7 = sext i16 %l7 to i64
  %m7 = mul nsw i64 %y7, %x
  %a7.next = add nsw i64 %m7, %a7
  %p8 = getelementptr inbounds i8, ptr %sp, i64 -14
  %l8 = load i16, ptr %p8, align 2
  %y8 = sext i16 %l8 to i64
  %m8 = mul nsw i64 %y8, %x
  %a8.next = add nsw i64 %m8, %a8
  %i.next = add nuw nsw i32 %i, 1
  %done = icmp eq i32 %i.next, 160
  br i1 %done, label %exit, label %loop

exit:
  store i64 %a0.next, ptr %L, align 8
  %L1 = getelementptr inbounds nuw i8, ptr %L, i64 8
  store i64 %a1.next, ptr %L1, align 8
  %L2 = getelementptr inbounds nuw i8, ptr %L, i64 16
  store i64 %a2.next, ptr %L2, align 8
  %L3 = getelementptr inbounds nuw i8, ptr %L, i64 24
  store i64 %a3.next, ptr %L3, align 8
  %L4 = getelementptr inbounds nuw i8, ptr %L, i64 32
  store i64 %a4.next, ptr %L4, align 8
  %L5 = getelementptr inbounds nuw i8, ptr %L, i64 40
  store i64 %a5.next, ptr %L5, align 8
  %L6 = getelementptr inbounds nuw i8, ptr %L, i64 48
  store i64 %a6.next, ptr %L6, align 8
  %L7 = getelementptr inbounds nuw i8, ptr %L, i64 56
  store i64 %a7.next, ptr %L7, align 8
  %L8 = getelementptr inbounds nuw i8, ptr %L, i64 64
  store i64 %a8.next, ptr %L8, align 8
  ret void
}

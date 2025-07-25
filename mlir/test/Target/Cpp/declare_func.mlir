// RUN: mlir-translate -mlir-to-cpp %s | FileCheck --match-full-lines %s

// CHECK: int32_t bar(int32_t [[V1:[^ ]*]]);
emitc.declare_func @bar
// CHECK:       int32_t bar(int32_t [[V1:[^ ]*]]) {
// CHECK-NEXT:      return [[V1]];
// CHECK-NEXT:  }
emitc.func @bar(%arg0: i32) -> i32 {
    emitc.return %arg0 : i32
}


// CHECK: static inline int32_t foo(int32_t [[V1:[^ ]*]]);
emitc.declare_func @foo
// CHECK: static inline int32_t foo(int32_t [[V1:[^ ]*]]) {
emitc.func @foo(%arg0: i32) -> i32 attributes {specifiers = ["static","inline"]} {
    emitc.return %arg0 : i32
}


// CHECK: void array_arg(int32_t [[V2:[^ ]*]][3]);
emitc.declare_func @array_arg
// CHECK: void array_arg(int32_t  [[V2:[^ ]*]][3]) {
emitc.func @array_arg(%arg0: !emitc.array<3xi32>) {
    emitc.return
}

// CHECK: int32_t foo1(int32_t [[V1:[^ ]*]]);
emitc.declare_func @foo1
// CHECK: int32_t foo2(int32_t [[V1]]);
emitc.declare_func @foo2
// CHECK: int32_t foo1(int32_t [[V1]]) {
emitc.func @foo1(%arg0: i32) -> i32 {
    // CHECK-NOT: int32_t [[V1]] = 0;
    %0 = "emitc.constant"() <{value = 0 : i32}> : () -> i32
    // CHECK: return [[V1]];
    emitc.return %arg0 : i32
}
// CHECK: int32_t foo2(int32_t [[V1]]) {
emitc.func @foo2(%arg0: i32) -> i32 {
    // CHECK: return [[V1]];
    emitc.return %arg0 : i32
}
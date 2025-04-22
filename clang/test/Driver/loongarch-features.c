// RUN: %clang --target=loongarch32 -S -emit-llvm %s -o - | FileCheck %s --check-prefix=LA32
// RUN: %clang --target=loongarch64 -S -emit-llvm %s -o - | FileCheck %s --check-prefix=LA64

// LA32: "target-features"="+la32r"
// LA64: "target-features"="+d,+f,+la64,+lsx,+ual"

int foo(void) {
  return 3;
}

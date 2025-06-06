#include <stdio.h>

int recurse(int x) {
  if (x <= 1)
    return 1;                // recurse end
  return recurse(x - 1) + x; // recurse call
}

int main(int argc, char const *argv[]) {
  recurse(40); // recurse invocation
  return 0;
}

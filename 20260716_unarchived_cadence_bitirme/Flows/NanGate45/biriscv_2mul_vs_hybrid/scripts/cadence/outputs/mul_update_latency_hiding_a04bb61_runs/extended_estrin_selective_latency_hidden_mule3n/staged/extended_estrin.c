#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

static int32_t xs[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    xs[i] = (i * 5 + 1) & 127;
  }
}

__attribute__((noinline))
static int64_t kernel_extended_estrin(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t x = xs[i];
    int32_t x2 = x * x;
    int32_t x4 = x2 * x2;
    int32_t x8 = x4 * x4;
    int32_t a0 = 1 + x * 3;
    int32_t a1 = 5 + x * 7;
    int32_t a2 = 11 + x * 13;
    int32_t a3 = 17 + x * 19;
    int32_t a4 = 23 + x * 29;
    int32_t a5 = 31 + x * 37;
    int32_t b0 = a0 + x2 * a1;
    int32_t b1 = a2 + x2 * a3;
    int32_t b2 = a4 + x2 * a5;
    int32_t c0 = b0 + x4 * b1;
    acc += c0 + x8 * b2;
  }
  return acc;
}

int main(void) {
  init();
  printf("extended_estrin=%lld\n", (long long)kernel_extended_estrin());
  return 0;
}

#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

static int32_t xs[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    xs[i] = (i * 9 + 5) & 127;
  }
}

__attribute__((noinline))
static int64_t kernel_estrin_poly(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t x = xs[i];
    int32_t x2 = x * x;
    int32_t x4 = x2 * x2;
    int32_t p0 = 2 + x * 3;
    int32_t p1 = 5 + x * 7;
    int32_t p2 = 11 + x * 13;
    int32_t p3 = 17 + x * 19;
    int32_t y0 = p0 + x2 * p1;
    int32_t y1 = p2 + x2 * p3;
    acc += y0 + x4 * y1;
  }
  return acc;
}

int main(void) {
  init();
  printf("estrin_poly=%lld\n", (long long)kernel_estrin_poly());
  return 0;
}

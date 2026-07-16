#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

static int32_t xs[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    xs[i] = (i * 7 + 3) & 127;
  }
}

__attribute__((noinline))
static int64_t kernel_estrin_2level(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t x = xs[i];
    int32_t x2 = x * x;
    int32_t g0 = 3 + x * 5;
    int32_t g1 = 7 + x * 11;
    int32_t g2 = 13 + x * 17;
    int32_t g3 = 19 + x * 23;
    int32_t h0 = g0 + x2 * g1;
    int32_t h1 = g2 + x2 * g3;
    acc += h0 + x2 * x2 * h1;
  }
  return acc;
}

int main(void) {
  init();
  printf("estrin_2level=%lld\n", (long long)kernel_estrin_2level());
  return 0;
}

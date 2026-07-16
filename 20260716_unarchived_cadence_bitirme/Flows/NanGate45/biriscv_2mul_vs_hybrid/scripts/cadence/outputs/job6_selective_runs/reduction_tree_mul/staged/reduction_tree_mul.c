#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t a[N], b[N], c[N], d[N], e[N], f[N], g[N], h[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    a[i] = (i * 3 + 1) & 31;
    b[i] = (i * 5 + 2) & 31;
    c[i] = (i * 7 + 3) & 31;
    d[i] = (i * 11 + 4) & 31;
    e[i] = (i * 13 + 5) & 31;
    f[i] = (i * 17 + 6) & 31;
    g[i] = (i * 19 + 7) & 31;
    h[i] = (i * 23 + 8) & 31;
  }
}

__attribute__((noinline))
static int64_t kernel_reduction_tree_mul(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t p0 = a[i] * b[i];
    int32_t p1 = c[i] * d[i];
    int32_t p2 = e[i] * f[i];
    int32_t p3 = g[i] * h[i];
    int32_t r0 = p0 + p1;
    int32_t r1 = p2 + p3;
    acc += r0 * r1;
  }
  return acc;
}

int main(void) {
  init();
  printf("reduction_tree_mul=%lld\n", (long long)kernel_reduction_tree_mul());
  return 0;
}

#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t a[N], b[N], c[N], d[N], e[N], f[N], g[N], h[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    a[i] = (i * 3 + 1) & 63;
    b[i] = (i * 5 + 2) & 63;
    c[i] = (i * 7 + 3) & 63;
    d[i] = (i * 11 + 4) & 63;
    e[i] = (i * 13 + 5) & 63;
    f[i] = (i * 17 + 6) & 63;
    g[i] = (i * 19 + 7) & 63;
    h[i] = (i * 23 + 8) & 63;
  }
}

__attribute__((noinline))
static int64_t kernel_multi_accumulator(void) {
  int64_t acc = 0;
  int32_t s0 = 0, s1 = 0, s2 = 0, s3 = 0, s4 = 0, s5 = 0, s6 = 0, s7 = 0;
  for (int i = 0; i < N; ++i) {
    s0 += a[i] * b[i];
    s1 += c[i] * d[i];
    s2 += e[i] * f[i];
    s3 += g[i] * h[i];
    s4 += a[i] * c[i];
    s5 += b[i] * d[i];
    s6 += e[i] * g[i];
    s7 += f[i] * h[i];
  }
  acc += s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7;
  return acc;
}

int main(void) {
  init();
  printf("multi_accumulator=%lld\n", (long long)kernel_multi_accumulator());
  return 0;
}

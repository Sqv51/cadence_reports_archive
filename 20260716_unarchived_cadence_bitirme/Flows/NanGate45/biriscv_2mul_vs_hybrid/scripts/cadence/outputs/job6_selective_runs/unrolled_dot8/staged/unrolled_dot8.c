#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t a[N], b[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    a[i] = (i * 3 + 1) & 63;
    b[i] = (i * 5 + 2) & 63;
  }
}

__attribute__((noinline))
static int64_t kernel_unrolled_dot8(void) {
  int32_t s0 = 0, s1 = 0, s2 = 0, s3 = 0, s4 = 0, s5 = 0, s6 = 0, s7 = 0;
  for (int i = 0; i < N; i += 8) {
    s0 += a[i + 0] * b[i + 0];
    s1 += a[i + 1] * b[i + 1];
    s2 += a[i + 2] * b[i + 2];
    s3 += a[i + 3] * b[i + 3];
    s4 += a[i + 4] * b[i + 4];
    s5 += a[i + 5] * b[i + 5];
    s6 += a[i + 6] * b[i + 6];
    s7 += a[i + 7] * b[i + 7];
  }
  return (int64_t)s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7;
}

int main(void) {
  init();
  printf("unrolled_dot8=%lld\n", (long long)kernel_unrolled_dot8());
  return 0;
}

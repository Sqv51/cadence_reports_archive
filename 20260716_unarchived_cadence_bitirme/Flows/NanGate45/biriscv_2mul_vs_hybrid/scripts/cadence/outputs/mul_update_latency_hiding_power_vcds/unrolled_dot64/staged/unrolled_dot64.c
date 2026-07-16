#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t a[N], b[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    a[i] = (i * 17 + 1) & 63;
    b[i] = (i * 19 + 2) & 63;
  }
}

__attribute__((noinline))
static int64_t kernel_unrolled_dot64(void) {
  int32_t s[64];
  for (int k = 0; k < 64; ++k) {
    s[k] = 0;
  }
  for (int i = 0; i < N; i += 64) {
    for (int k = 0; k < 64; ++k) {
      s[k] += a[i + k] * b[i + k];
    }
  }
  int64_t sum = 0;
  for (int k = 0; k < 64; ++k) {
    sum += s[k];
  }
  return sum;
}

int main(void) {
  init();
  printf("unrolled_dot64=%lld\n", (long long)kernel_unrolled_dot64());
  return 0;
}

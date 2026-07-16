#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t a[N], b[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    a[i] = (i * 7 + 1) & 63;
    b[i] = (i * 9 + 2) & 63;
  }
}

__attribute__((noinline))
static int64_t kernel_unrolled_dot16(void) {
  int32_t s[16];
  for (int k = 0; k < 16; ++k) {
    s[k] = 0;
  }
  for (int i = 0; i < N; i += 16) {
    for (int k = 0; k < 16; ++k) {
      s[k] += a[i + k] * b[i + k];
    }
  }
  int64_t sum = 0;
  for (int k = 0; k < 16; ++k) {
    sum += s[k];
  }
  return sum;
}

int main(void) {
  init();
  printf("unrolled_dot16=%lld\n", (long long)kernel_unrolled_dot16());
  return 0;
}

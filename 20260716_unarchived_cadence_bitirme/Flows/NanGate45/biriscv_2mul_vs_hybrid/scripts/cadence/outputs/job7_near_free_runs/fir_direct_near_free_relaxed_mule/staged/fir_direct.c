#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

#ifndef K
#define K 16
#endif

static int32_t x[N];
static int32_t h[K];
static int32_t y[N];

static void init(void) {
  for (int i = 0; i < N; i++) {
    x[i] = (i * 3 + 1) % 17;
    y[i] = 0;
  }
  for (int k = 0; k < K; k++) {
    h[k] = (k * 5 + 7) % 19;
  }
}

__attribute__((noinline))
static void kernel_fir_direct(void) {
  for (int i = K; i < N; i++) {
    int32_t acc = 0;
    for (int k = 0; k < K; k++) {
      acc += x[i - k] * h[k];
    }
    y[i] = acc;
  }
}

static long long checksum(void) {
  long long sum = 0;
  for (int i = 0; i < N; i++) {
    sum += y[i];
  }
  return sum;
}

int main(void) {
  init();
  kernel_fir_direct();
  printf("fir_direct_sum=%lld\n", checksum());
  return 0;
}
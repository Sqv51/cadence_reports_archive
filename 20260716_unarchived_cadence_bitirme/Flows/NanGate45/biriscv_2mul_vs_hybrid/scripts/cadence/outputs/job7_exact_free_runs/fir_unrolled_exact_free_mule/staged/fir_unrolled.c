#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

#ifndef K
#define K 16
#endif

static int32_t x[N + K];
static int32_t h[K];
static int32_t y[N];

static void init(void) {
  for (int i = 0; i < N + K; i++) {
    x[i] = (i * 3 + 1) % 17;
  }
  for (int k = 0; k < K; k++) {
    h[k] = (k * 5 + 7) % 19;
  }
  for (int i = 0; i < N; i++) {
    y[i] = 0;
  }
}

__attribute__((noinline))
static void kernel_fir_unrolled(void) {
  int i = K;
  for (; i + 3 < N; i += 4) {
    int32_t acc0 = 0;
    int32_t acc1 = 0;
    int32_t acc2 = 0;
    int32_t acc3 = 0;
    for (int k = 0; k < K; k++) {
      int32_t hk = h[k];
      acc0 += x[i - k] * hk;
      acc1 += x[i + 1 - k] * hk;
      acc2 += x[i + 2 - k] * hk;
      acc3 += x[i + 3 - k] * hk;
    }
    y[i] = acc0;
    y[i + 1] = acc1;
    y[i + 2] = acc2;
    y[i + 3] = acc3;
  }

  for (; i < N; i++) {
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
  kernel_fir_unrolled();
  printf("fir_unrolled_sum=%lld\n", checksum());
  return 0;
}
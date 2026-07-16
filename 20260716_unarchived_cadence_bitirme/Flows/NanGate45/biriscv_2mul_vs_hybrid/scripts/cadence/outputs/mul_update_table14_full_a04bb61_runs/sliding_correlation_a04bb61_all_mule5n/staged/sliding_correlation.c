#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 192
#endif

#ifndef TAPS
#define TAPS 16
#endif

static int32_t signal_in[N + TAPS];
static int32_t kernel[TAPS];

static void init(void) {
  for (int i = 0; i < N + TAPS; ++i) {
    signal_in[i] = (i * 7 + 3) & 63;
  }
  for (int i = 0; i < TAPS; ++i) {
    kernel[i] = (i * 5 + 1) & 31;
  }
}

__attribute__((noinline))
static int64_t kernel_sliding_correlation(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t sum = 0;
    for (int t = 0; t < TAPS; ++t) {
      sum += signal_in[i + t] * kernel[t];
    }
    acc += sum;
  }
  return acc;
}

int main(void) {
  init();
  printf("sliding_correlation=%lld\n", (long long)kernel_sliding_correlation());
  return 0;
}

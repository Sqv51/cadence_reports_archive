#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

#ifndef TAPS
#define TAPS 16
#endif

static int32_t signal_in[N + TAPS + 4];
static int32_t coeff0[TAPS], coeff1[TAPS], coeff2[TAPS], coeff3[TAPS];

static void init(void) {
  for (int i = 0; i < N + TAPS + 4; ++i) {
    signal_in[i] = (i * 11 + 5) & 63;
  }
  for (int t = 0; t < TAPS; ++t) {
    coeff0[t] = (t * 3 + 1) & 31;
    coeff1[t] = (t * 5 + 2) & 31;
    coeff2[t] = (t * 7 + 3) & 31;
    coeff3[t] = (t * 9 + 4) & 31;
  }
}

__attribute__((noinline))
static int64_t kernel_filter_bank_4out(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t y0 = 0, y1 = 0, y2 = 0, y3 = 0;
    for (int t = 0; t < TAPS; ++t) {
      int32_t s = signal_in[i + t];
      y0 += s * coeff0[t];
      y1 += s * coeff1[t];
      y2 += s * coeff2[t];
      y3 += s * coeff3[t];
    }
    acc += y0 + y1 + y2 + y3;
  }
  return acc;
}

int main(void) {
  init();
  printf("filter_bank_4out=%lld\n", (long long)kernel_filter_bank_4out());
  return 0;
}

#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 192
#endif

#ifndef TAPS
#define TAPS 12
#endif

static int32_t signal_in[N + TAPS];
static int32_t templ[4][TAPS];

static void init(void) {
  for (int i = 0; i < N + TAPS; ++i) {
    signal_in[i] = (i * 13 + 7) & 63;
  }
  for (int g = 0; g < 4; ++g) {
    for (int t = 0; t < TAPS; ++t) {
      templ[g][t] = ((g + 1) * (t + 3) + 5) & 31;
    }
  }
}

__attribute__((noinline))
static int64_t kernel_grouped_correlation_bank(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t s0 = 0, s1 = 0, s2 = 0, s3 = 0;
    for (int t = 0; t < TAPS; ++t) {
      int32_t x = signal_in[i + t];
      s0 += x * templ[0][t];
      s1 += x * templ[1][t];
      s2 += x * templ[2][t];
      s3 += x * templ[3][t];
    }
    acc += s0 + s1 + s2 + s3;
  }
  return acc;
}

int main(void) {
  init();
  printf("grouped_correlation_bank=%lld\n", (long long)kernel_grouped_correlation_bank());
  return 0;
}

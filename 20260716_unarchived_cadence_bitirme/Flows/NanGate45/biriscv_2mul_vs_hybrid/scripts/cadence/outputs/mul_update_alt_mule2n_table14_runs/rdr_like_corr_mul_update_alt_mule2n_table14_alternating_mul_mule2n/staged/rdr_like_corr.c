#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 192
#endif

#ifndef TAPS
#define TAPS 8
#endif

static int32_t ref_i[N + TAPS], ref_q[N + TAPS];
static int32_t ker_i[TAPS], ker_q[TAPS];

static void init(void) {
  for (int i = 0; i < N + TAPS; ++i) {
    ref_i[i] = (i * 5 + 1) & 63;
    ref_q[i] = (i * 9 + 3) & 63;
  }
  for (int i = 0; i < TAPS; ++i) {
    ker_i[i] = (i * 7 + 2) & 31;
    ker_q[i] = (i * 11 + 4) & 31;
  }
}

__attribute__((noinline))
static int64_t kernel_rdr_like_corr(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t r = 0;
    int32_t q = 0;
    for (int t = 0; t < TAPS; ++t) {
      r += ref_i[i + t] * ker_i[t] + ref_q[i + t] * ker_q[t];
      q += ref_q[i + t] * ker_i[t] - ref_i[i + t] * ker_q[t];
    }
    acc += r + q;
  }
  return acc;
}

int main(void) {
  init();
  printf("rdr_like_corr=%lld\n", (long long)kernel_rdr_like_corr());
  return 0;
}

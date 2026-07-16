#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 128
#endif

static int32_t ar0[N], ai0[N], br0[N], bi0[N];
static int32_t ar1[N], ai1[N], br1[N], bi1[N];
static int32_t ar2[N], ai2[N], br2[N], bi2[N];
static int32_t ar3[N], ai3[N], br3[N], bi3[N];

static void init(void) {
  for (int i = 0; i < N; ++i) {
    ar0[i] = (i * 3 + 1) & 31;
    ai0[i] = (i * 5 + 2) & 31;
    br0[i] = (i * 7 + 3) & 31;
    bi0[i] = (i * 11 + 4) & 31;
    ar1[i] = (i * 13 + 5) & 31;
    ai1[i] = (i * 17 + 6) & 31;
    br1[i] = (i * 19 + 7) & 31;
    bi1[i] = (i * 23 + 8) & 31;
    ar2[i] = (i * 29 + 9) & 31;
    ai2[i] = (i * 31 + 10) & 31;
    br2[i] = (i * 37 + 11) & 31;
    bi2[i] = (i * 41 + 12) & 31;
    ar3[i] = (i * 43 + 13) & 31;
    ai3[i] = (i * 47 + 14) & 31;
    br3[i] = (i * 53 + 15) & 31;
    bi3[i] = (i * 59 + 16) & 31;
  }
}

__attribute__((noinline))
static int64_t kernel_complex_bank(void) {
  int64_t acc = 0;
  for (int i = 0; i < N; ++i) {
    int32_t r0 = ar0[i] * br0[i] - ai0[i] * bi0[i];
    int32_t i0 = ar0[i] * bi0[i] + ai0[i] * br0[i];
    int32_t r1 = ar1[i] * br1[i] - ai1[i] * bi1[i];
    int32_t i1 = ar1[i] * bi1[i] + ai1[i] * br1[i];
    int32_t r2 = ar2[i] * br2[i] - ai2[i] * bi2[i];
    int32_t i2 = ar2[i] * bi2[i] + ai2[i] * br2[i];
    int32_t r3 = ar3[i] * br3[i] - ai3[i] * bi3[i];
    int32_t i3 = ar3[i] * bi3[i] + ai3[i] * br3[i];
    acc += r0 + i0 + r1 + i1 + r2 + i2 + r3 + i3;
  }
  return acc;
}

int main(void) {
  init();
  printf("complex_bank=%lld\n", (long long)kernel_complex_bank());
  return 0;
}

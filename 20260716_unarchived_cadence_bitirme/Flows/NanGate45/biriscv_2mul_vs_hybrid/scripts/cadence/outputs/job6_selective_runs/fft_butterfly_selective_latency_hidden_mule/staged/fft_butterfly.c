#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 256
#endif

static int32_t xr0[N];
static int32_t xi0[N];
static int32_t xr1[N];
static int32_t xi1[N];
static int32_t wr[N];
static int32_t wi[N];
static int32_t yr0[N];
static int32_t yi0[N];
static int32_t yr1[N];
static int32_t yi1[N];

static void init(void) {
  for (int i = 0; i < N; i++) {
    xr0[i] = (i * 3 + 1) % 17;
    xi0[i] = (i * 5 + 2) % 19;
    xr1[i] = (i * 7 + 4) % 23;
    xi1[i] = (i * 11 + 6) % 29;
    wr[i] = (i * 13 + 1) % 31;
    wi[i] = (i * 17 + 3) % 37;
    yr0[i] = 0;
    yi0[i] = 0;
    yr1[i] = 0;
    yi1[i] = 0;
  }
}

__attribute__((noinline))
static void kernel_fft_butterfly(void) {
  for (int i = 0; i < N; i++) {
    int32_t tr = xr1[i] * wr[i] - xi1[i] * wi[i];
    int32_t ti = xr1[i] * wi[i] + xi1[i] * wr[i];
    yr0[i] = xr0[i] + tr;
    yi0[i] = xi0[i] + ti;
    yr1[i] = xr0[i] - tr;
    yi1[i] = xi0[i] - ti;
  }
}

static long long checksum(void) {
  long long sum = 0;
  for (int i = 0; i < N; i++) {
    sum += yr0[i] + yi0[i] + yr1[i] + yi1[i];
  }
  return sum;
}

int main(void) {
  init();
  kernel_fft_butterfly();
  printf("fft_butterfly_sum=%lld\n", checksum());
  return 0;
}
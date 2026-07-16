#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 512
#endif

typedef struct {
  int32_t re;
  int32_t im;
} complex_i32_t;

static complex_i32_t a[N];
static complex_i32_t b[N];
static complex_i32_t out[N];

static void init(void) {
  for (int i = 0; i < N; i++) {
    a[i].re = (i * 7 + 3) % 31;
    a[i].im = (i * 5 + 9) % 29;
    b[i].re = (i * 11 + 1) % 23;
    b[i].im = (i * 13 + 5) % 19;
    out[i].re = 0;
    out[i].im = 0;
  }
}

__attribute__((noinline))
static void kernel_complex_mul_vec(void) {
  for (int i = 0; i < N; i++) {
    int32_t ar = a[i].re;
    int32_t ai = a[i].im;
    int32_t br = b[i].re;
    int32_t bi = b[i].im;
    int32_t real = ar * br - ai * bi;
    int32_t imag = ar * bi + ai * br;

    out[i].re = real;
    out[i].im = imag;
  }
}

static long long checksum(void) {
  long long sum = 0;
  for (int i = 0; i < N; i++) {
    sum += out[i].re;
    sum += out[i].im;
  }
  return sum;
}

int main(void) {
  init();
  kernel_complex_mul_vec();
  printf("complex_mul_vec_sum=%lld\n", checksum());
  return 0;
}
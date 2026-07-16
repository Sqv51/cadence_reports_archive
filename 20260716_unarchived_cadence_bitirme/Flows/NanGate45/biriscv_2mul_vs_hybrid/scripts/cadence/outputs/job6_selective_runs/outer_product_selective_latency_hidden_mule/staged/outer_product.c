#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 48
#endif

static int32_t a[N];
static int32_t b[N];
static int32_t c[N][N];

static void init(void) {
  for (int i = 0; i < N; i++) {
    a[i] = (i * 3 + 1) % 17;
    b[i] = (i * 5 + 7) % 19;
    for (int j = 0; j < N; j++) {
      c[i][j] = (i + j) & 3;
    }
  }
}

__attribute__((noinline))
static void kernel_outer_product(void) {
  for (int i = 0; i < N; i++) {
    int32_t ai = a[i];
    for (int j = 0; j < N; j++) {
      c[i][j] += ai * b[j];
    }
  }
}

static long long checksum(void) {
  long long sum = 0;
  for (int i = 0; i < N; i++) {
    for (int j = 0; j < N; j++) {
      sum += c[i][j];
    }
  }
  return sum;
}

int main(void) {
  init();
  kernel_outer_product();
  printf("outer_product_sum=%lld\n", checksum());
  return 0;
}
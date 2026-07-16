#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 1024
#endif

static int32_t A[N];
static int32_t B[N];

static void init() {
  for (int i = 0; i < N; i++) {
    A[i] = (i * 3 + 1) % 17;
    B[i] = (i * 5 + 7) % 19;
  }
}

int main() {
  init();

  long long sum = 0;

  for (int i = 0; i < N; i++) {
    sum += (long long)A[i] * (long long)B[i];
  }

  printf("dot=%lld\n", sum);
  return 0;
}

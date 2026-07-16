#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 32
#endif

#ifndef TILE
#define TILE 8
#endif

static int32_t A[N][N];
static int32_t B[N][N];
static int32_t C[N][N];

static void init(void) {
  for (int i = 0; i < N; i++) {
    for (int j = 0; j < N; j++) {
      A[i][j] = (i + 3 * j) % 17;
      B[i][j] = (2 * i - j) % 19;
      C[i][j] = 0;
    }
  }
}

__attribute__((noinline))
static void kernel_matmul_tiled(void) {
  for (int ii = 0; ii < N; ii += TILE) {
    for (int kk = 0; kk < N; kk += TILE) {
      for (int jj = 0; jj < N; jj += TILE) {
        for (int i = ii; i < ii + TILE; i++) {
          for (int k = kk; k < kk + TILE; k++) {
            int32_t aik = A[i][k];
            for (int j = jj; j < jj + TILE; j++) {
              C[i][j] += aik * B[k][j];
            }
          }
        }
      }
    }
  }
}

static long long checksum(void) {
  long long sum = 0;
  for (int i = 0; i < N; i++) {
    for (int j = 0; j < N; j++) {
      sum += C[i][j];
    }
  }
  return sum;
}

int main(void) {
  init();
  kernel_matmul_tiled();
  printf("matmul_tiled_sum=%lld\n", checksum());
  return 0;
}
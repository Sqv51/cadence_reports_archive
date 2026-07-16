#include <stdint.h>
#include <stdio.h>

#ifndef N
#define N 96
#endif

static volatile int32_t lhs[N];
static volatile int32_t rhs[N];

__attribute__((noinline))
static uint32_t ref_mul32(uint32_t a, uint32_t b) {
  uint32_t acc = 0;
  for (unsigned bit = 0; bit < 32; ++bit) {
    if ((b >> bit) & 1u) {
      acc += (a << bit);
    }
  }
  return acc;
}

static void init(void) {
  static const int32_t seeds[] = {
      0, 1, -1, 2, -2, 3, -3, 7, -7, 15, -15, 31, -31,
      63, -63, 127, -127, 255, -255, 1024, -1024, 32767,
      -32768, 65535, -65536, 0x12345678, (int32_t)0x87654321u,
      0x40000000, (int32_t)0x80000000u, 0x7fffffff,
      (int32_t)0xffffffffu, 0x13579bdf, (int32_t)0xfdb97531u};

  const unsigned count = sizeof(seeds) / sizeof(seeds[0]);
  unsigned seed_b = 3u;
  uint32_t step_a = 0x9e3779b9u;
  uint32_t step_b = 0x7f4a7c15u;
  for (unsigned i = 0; i < N; ++i) {
    uint32_t mix_a = (uint32_t)seeds[i % count];
    uint32_t mix_b = (uint32_t)seeds[seed_b];
    lhs[i] = (int32_t)(mix_a ^ step_a);
    rhs[i] = (int32_t)(mix_b + step_b);

    seed_b += 7u;
    if (seed_b >= count) {
      seed_b -= count;
    }
    step_a += 0x9e3779b9u;
    step_b ^= 0x45d9f3bu + i;
  }
}

__attribute__((noinline))
static uint32_t kernel_multiplier_correctness(void) {
  uint32_t signature = 0;

  for (unsigned repeat = 0; repeat < 5; ++repeat) {
    unsigned rhs_index = repeat;
    for (unsigned offset_step = 0; offset_step < repeat; ++offset_step) {
      rhs_index += 12u;
      if (rhs_index >= N) {
        rhs_index -= N;
      }
    }

    for (unsigned i = 0; i < N; ++i) {
      int32_t a = lhs[i];
      int32_t b = rhs[rhs_index];
      uint32_t got = (uint32_t)(a * b);
      uint32_t expect = ref_mul32((uint32_t)a, (uint32_t)b);

      if (got != expect) {
        printf("mul_mismatch repeat=%u index=%u a=%ld b=%ld got=0x%08lx expect=0x%08lx\n",
               repeat,
               i,
               (long)a,
               (long)b,
               (unsigned long)got,
               (unsigned long)expect);
        return 0xdead0000u | (repeat << 8) | i;
      }

      signature ^= got + 0x9e3779b9u + (signature << 6) + (signature >> 2);
      rhs_index++;
      if (rhs_index == N) {
        rhs_index = 0;
      }
    }
  }

  return signature;
}

int main(void) {
  init();
  uint32_t signature = kernel_multiplier_correctness();
  printf("multiplier_correctness=0x%08lx\n", (unsigned long)signature);
  return (signature & 0xffff0000u) == 0xdead0000u;
}

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${SCRIPT_DIR}/generate_benchmark_vcds_xrun.py"
OUT_ROOT="${SCRIPT_DIR}/outputs/job7_exact_free_runs"
TABLE14_DIR="${SCRIPT_DIR}/benchmarks/table14"
FILTER_LIST="${JOB7_BENCH_FILTER:-}"

should_run_bench() {
  local bench="$1"
  if [[ -z "${FILTER_LIST}" ]]; then
    return 0
  fi

  local item
  IFS=',' read -r -a filter_items <<< "${FILTER_LIST}"
  for item in "${filter_items[@]}"; do
    if [[ "${bench}" == "${item}" ]]; then
      return 0
    fi
  done
  return 1
}

run_benchmark_pair() {
  local src="$1"
  local bench="$2"
  shift 2
  local baseline_json="${OUT_ROOT}/${bench}/metrics/core_hybrid.json"
  local oracle_json="${OUT_ROOT}/${bench}_exact_free_mule/metrics/core_hybrid.json"

  if [[ ! -f "${src}" ]]; then
    echo "missing benchmark source: ${src}" >&2
    exit 1
  fi

  if [[ -f "${baseline_json}" ]]; then
    echo "=== ${bench}: baseline already present, skipping ==="
  else
    echo "=== ${bench}: baseline no-VCD ==="
    python3.11 "${GEN}" "${src}" \
      --benchmark-name "${bench}" \
      --config hybrid \
      --variant baseline \
      --no-vcd \
      --output-root "${OUT_ROOT}" \
      "$@"
  fi

  if [[ -f "${oracle_json}" ]]; then
    echo "=== ${bench}: exact-free-mule already present, skipping ==="
  else
    echo "=== ${bench}: exact-free-mule oracle ==="
    python3.11 "${GEN}" "${src}" \
      --benchmark-name "${bench}" \
      --config hybrid \
      --variant exact-free-mule \
      --latency-distance-threshold 6 \
      --output-root "${OUT_ROOT}" \
      "$@"
  fi
}

ORIGINAL_BENCHMARKS=(
  "complex_mul_vec:${SCRIPT_DIR}/outputs/benchmark_runs/complex_mul_vec/staged/complex_mul_vec.c"
  "fft_butterfly:${SCRIPT_DIR}/outputs/benchmark_runs/fft_butterfly/staged/fft_butterfly.c"
  "fir_direct:${SCRIPT_DIR}/outputs/benchmark_runs/fir_direct/staged/fir_direct.c"
  "fir_unrolled:${SCRIPT_DIR}/outputs/benchmark_runs/fir_unrolled/staged/fir_unrolled.c"
  "matmul_tiled:${SCRIPT_DIR}/outputs/benchmark_runs/matmul_tiled/staged/matmul_tiled.c"
  "outer_product:${SCRIPT_DIR}/outputs/benchmark_runs/outer_product/staged/outer_product.c"
)

TABLE14_BENCHMARKS=(
  complex_bank
  estrin_2level
  estrin_poly
  extended_estrin
  filter_bank_4out
  grouped_correlation_bank
  multi_accumulator
  rdr_like_corr
  reduction_tree_mul
  sliding_correlation
  unrolled_dot8
  unrolled_dot16
  unrolled_dot32
  unrolled_dot64
)

for item in "${ORIGINAL_BENCHMARKS[@]}"; do
  bench="${item%%:*}"
  src="${item#*:}"
  if ! should_run_bench "${bench}"; then
    continue
  fi
  run_benchmark_pair "${src}" "${bench}" "$@"
done

for bench in "${TABLE14_BENCHMARKS[@]}"; do
  if ! should_run_bench "${bench}"; then
    continue
  fi
  run_benchmark_pair "${TABLE14_DIR}/${bench}.c" "${bench}" "$@"
done

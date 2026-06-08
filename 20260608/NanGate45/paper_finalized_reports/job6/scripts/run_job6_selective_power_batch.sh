#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$ROOT/run_benchmark_power_from_vcd.py"
ENC="$ROOT/outputs/innovus/core_hybrid_100/vcd/enc/core_hybrid_100.enc"
RUN_ROOT="$ROOT/outputs/job6_selective_runs"
OUT_ROOT="$ROOT/outputs/job6_selective_power"
SCOPE="tb_matmul_absorbtion.u_dut"
FILTER_LIST="${JOB6_BENCH_FILTER:-}"

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

BENCHMARKS=(
  complex_mul_vec
  fft_butterfly
  fir_direct
  fir_unrolled
  matmul_tiled
  outer_product
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

run_case() {
  local bench="$1"
  local flavor="$2"
  local vcd="$3"
  local out_dir="$OUT_ROOT/$bench/$flavor/reports"
  local done_report="$out_dir/power_total.rpt"

  if [[ -f "$done_report" ]]; then
    echo "=== Skipping $bench / $flavor (report already present) ==="
    return 0
  fi

  echo "=== Running $bench / $flavor ==="
  python3.11 "$RUNNER" \
    --design core_hybrid \
    --benchmark-name "${bench}_${flavor}_job6_selective" \
    --vcd "$vcd" \
    --vcd-scope "$SCOPE" \
    --vcd-clock-name clk \
    --vcd-clock-scale-factor 1.0 \
    --enc-script "$ENC" \
    --output-dir "$out_dir" \
    --report-inst-a u_mul \
    --report-inst-b u_mule
}

for bench in "${BENCHMARKS[@]}"; do
  if ! should_run_bench "${bench}"; then
    continue
  fi
  run_case "$bench" "baseline" \
    "$RUN_ROOT/$bench/vcd/core_hybrid.vcd"
  run_case "$bench" "selective" \
    "$RUN_ROOT/${bench}_selective_latency_hidden_mule/vcd/core_hybrid.vcd"
done

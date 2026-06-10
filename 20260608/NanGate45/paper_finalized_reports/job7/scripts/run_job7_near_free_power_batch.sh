#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$ROOT/run_benchmark_power_from_vcd.py"
ENC="$ROOT/outputs/innovus/core_hybrid_100/vcd/enc/core_hybrid_100.enc"
RUN_ROOT="$ROOT/outputs/job7_near_free_runs"
OUT_ROOT="$ROOT/outputs/job7_near_free_power"
SCOPE="tb_matmul_absorbtion.u_dut"
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
  local metrics="$RUN_ROOT/${bench}_near_free_relaxed_mule/metrics/core_hybrid.json"
  local vcd="$RUN_ROOT/${bench}_near_free_relaxed_mule/vcd/core_hybrid.vcd"
  local out_dir="$OUT_ROOT/$bench/oracle/reports"
  local done_report="$out_dir/power_total.rpt"

  if [[ ! -f "$metrics" ]]; then
    echo "=== Skipping $bench (missing near-free oracle metrics) ==="
    return 0
  fi
  if ! python3.11 - "$metrics" <<'PY'
import json, sys
data = json.load(open(sys.argv[1], encoding="utf-8"))
raise SystemExit(0 if int(data.get("patched_plain_mul_count", 0)) > 0 else 1)
PY
  then
    echo "=== Skipping $bench (zero accepted near-free patches) ==="
    return 0
  fi
  if [[ ! -f "$vcd" ]]; then
    echo "missing accepted near-free oracle VCD: $vcd" >&2
    exit 1
  fi
  if [[ -f "$done_report" ]]; then
    echo "=== Skipping $bench / near-free oracle (report already present) ==="
    return 0
  fi

  echo "=== Running $bench / near-free oracle ==="
  python3.11 "$RUNNER" \
    --design core_hybrid \
    --benchmark-name "${bench}_oracle_job7_near_free" \
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
  run_case "$bench"
done

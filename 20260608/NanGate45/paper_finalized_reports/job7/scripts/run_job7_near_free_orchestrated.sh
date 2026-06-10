#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN_SCRIPT="$ROOT/run_job7_near_free_batch.sh"
POWER_SCRIPT="$ROOT/run_job7_near_free_power_batch.sh"
RUN_ROOT="$ROOT/outputs/job7_near_free_runs"
POWER_ROOT="$ROOT/outputs/job7_near_free_power"
FILTER_LIST="${JOB7_BENCH_FILTER:-}"

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

accepted_patch_count() {
  local metrics="$1"
  if [[ ! -f "$metrics" ]]; then
    echo 0
    return 0
  fi
  python3.11 - "$metrics" <<'PY'
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
print(int(data.get("patched_plain_mul_count", 0)))
PY
}

for bench in "${BENCHMARKS[@]}"; do
  if ! should_run_bench "$bench"; then
    continue
  fi

  echo "=== Job 7 near-free orchestrated: $bench ==="
  JOB7_BENCH_FILTER="$bench" "$RUN_SCRIPT"

  metrics="$RUN_ROOT/${bench}_near_free_relaxed_mule/metrics/core_hybrid.json"
  patches="$(accepted_patch_count "$metrics")"
  if [[ "$patches" -le 0 ]]; then
    echo "=== $bench: zero accepted near-free patches; no power replay needed ==="
    continue
  fi

  JOB7_BENCH_FILTER="$bench" "$POWER_SCRIPT"

  report="$POWER_ROOT/$bench/oracle/reports/power_total.rpt"
  vcd="$RUN_ROOT/${bench}_near_free_relaxed_mule/vcd/core_hybrid.vcd"
  if [[ -f "$report" && -f "$vcd" ]]; then
    echo "=== $bench: deleting replayed VCD to conserve storage ==="
    rm -f "$vcd"
  fi
  df -h "$ROOT" | tail -n 1
done

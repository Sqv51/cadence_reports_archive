#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$ROOT/run_benchmark_power_from_vcd.py"
ENC="$ROOT/outputs/innovus/core_hybrid_100/vcd/enc/core_hybrid_100.enc"
OUT_ROOT="$ROOT/outputs/benchmark_power_job4"
SCOPE="tb_matmul_absorbtion.u_dut"

run_case() {
  local bench="$1"
  local flavor="$2"
  local vcd="$3"
  local out_dir="$OUT_ROOT/$bench/$flavor/reports"

  echo "=== Running $bench / $flavor ==="
  python3.11 "$RUNNER" \
    --design core_hybrid \
    --benchmark-name "${bench}_${flavor}_job4" \
    --vcd "$vcd" \
    --vcd-scope "$SCOPE" \
    --vcd-clock-name clk \
    --vcd-clock-scale-factor 1.0 \
    --enc-script "$ENC" \
    --output-dir "$out_dir" \
    --report-inst-a u_mul \
    --report-inst-b u_mule
}

run_case "complex_mul_vec" "baseline" \
  "$ROOT/outputs/benchmark_runs/complex_mul_vec/vcd/core_hybrid.vcd"
run_case "complex_mul_vec" "switched" \
  "$ROOT/outputs/benchmark_runs/complex_mul_vec_latency_hidden_mule/vcd/core_hybrid.vcd"

run_case "fft_butterfly" "baseline" \
  "$ROOT/outputs/benchmark_runs_1ghz_exact_free/fft_butterfly/vcd/core_hybrid.vcd"
run_case "fft_butterfly" "switched" \
  "$ROOT/outputs/benchmark_runs_1ghz_exact_free/fft_butterfly_latency_hidden_mule/vcd/core_hybrid.vcd"

run_case "fir_direct" "baseline" \
  "$ROOT/outputs/benchmark_runs/fir_direct/vcd/core_hybrid.vcd"
run_case "fir_direct" "switched" \
  "$ROOT/outputs/benchmark_runs/fir_direct_latency_hidden_mule/vcd/core_hybrid.vcd"

run_case "fir_unrolled" "baseline" \
  "$ROOT/outputs/benchmark_runs_1ghz_exact_free/fir_unrolled/vcd/core_hybrid.vcd"
run_case "fir_unrolled" "switched" \
  "$ROOT/outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/work/core_hybrid/waveform.vcd"

run_case "matmul_tiled" "baseline" \
  "$ROOT/outputs/benchmark_runs/matmul_tiled/vcd/core_hybrid.vcd"
run_case "matmul_tiled" "switched" \
  "$ROOT/outputs/benchmark_runs/matmul_tiled_latency_hidden_mule/vcd/core_hybrid.vcd"

run_case "outer_product" "baseline" \
  "$ROOT/outputs/benchmark_runs/outer_product/work/core_hybrid/waveform.vcd"
run_case "outer_product" "switched" \
  "$ROOT/outputs/benchmark_runs/outer_product_latency_hidden_mule/vcd/core_hybrid.vcd"

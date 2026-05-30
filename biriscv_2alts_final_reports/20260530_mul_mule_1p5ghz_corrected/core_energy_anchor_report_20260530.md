# Core-Level Energy Anchor Report (2standard vs hybrid)

Date: 2026-05-30
Flow: NanGate45 biriscv_2mul_vs_hybrid

## Scope
This report consolidates the best currently validated core-level energy-saving cases and one boundary counterexample:
- complex_mul_vec (best absolute savings)
- fft_butterfly (near-best corroborating savings)
- fft_butterfly_latency_hidden_mule (best explicit MULE / latency-hidden savings)
- fir_unrolled_latency_hidden_mule (boundary case)

Power values are from saved Innovus report-only runs.
Cycle and integer-multiply counts are from benchmark metrics JSON outputs.

## Results

### 1) complex_mul_vec
- core_2standard power_total: 8.28929158 mW
- core_hybrid power_total: 7.39347994 mW
- cycles: 109170 vs 109170
- integer multiply ops: 2048 vs 2048
- E/op (pJ): 441866.192280 vs 394114.357934
- hybrid delta: -47751.834346 pJ/op (-10.806854%)

Interpretation: This is the strongest validated core-energy saving case currently available; hybrid cuts total core energy per multiply without any cycle penalty.

### 2) fft_butterfly
- core_2standard power_total: 8.35169996 mW
- core_hybrid power_total: 7.45703880 mW
- cycles: 84951 vs 84951
- integer multiply ops: 1024 vs 1024
- E/op (pJ): 692856.702443 vs 618635.647557
- hybrid delta: -74221.054886 pJ/op (-10.712324%)

Interpretation: This closely corroborates the same thesis point as complex_mul_vec, with almost identical savings and no cycle penalty.

### 3) fft_butterfly_latency_hidden_mule
- core_2standard power_total: 8.33314691 mW
- core_hybrid power_total: 7.46215293 mW
- cycles: 86993 vs 87249
- integer multiply ops: 1024 vs 1024
- E/op (pJ): 707935.008927 vs 635806.036123
- hybrid delta: -72128.972804 pJ/op (-10.188643%)

Interpretation: This is the best explicit MULE/latency-hidden positive case; the hybrid still saves core energy despite a small cycle increase.

### 4) fir_unrolled_latency_hidden_mule
- core_2standard power_total: 8.71725369 mW
- core_hybrid power_total: 7.82746974 mW
- cycles: 185715 vs 214443
- integer multiply ops: 16128 vs 16128
- E/op (pJ): 1003.797600 vs 1040.765187
- hybrid delta: +36.967587 pJ/op (+3.682773%)

Interpretation: Hybrid reduces average power but increased cycles dominate total energy per multiply operation in this workload/configuration.

## Cross-benchmark takeaways
- Core-level energy savings are workload dependent.
- The largest currently validated savings are complex_mul_vec (-10.806854%) and fft_butterfly (-10.712324%).
- The best explicit latency-hidden MULE case is fft_butterfly_latency_hidden_mule (-10.188643%).
- Hybrid can lose E/op when cycle inflation outweighs power reduction (fir_unrolled_latency_hidden_mule).

## Energy-first thesis framing
- The primary thesis claim should be based on E/op, not peak-window behavior.
- complex_mul_vec is the strongest headline energy-saving case: hybrid cuts core power by 10.806854% with no cycle penalty, so E/op improves by the same 10.806854%.
- fft_butterfly independently corroborates the same effect with a 10.712324% E/op improvement.
- fft_butterfly_latency_hidden_mule is the strongest explicit latency-hidden MULE case: hybrid cuts core power by 10.452162% and only pays a 0.294277% cycle increase, so E/op still improves by 10.188643%.
- fir_unrolled_latency_hidden_mule is the boundary case: hybrid cuts core power by 10.207159%, but cycle count rises by 15.468864%, so E/op worsens by 3.682773%.
- Recommended thesis wording: use complex_mul_vec as the headline savings result, fft_butterfly as corroboration, and fft_butterfly_latency_hidden_mule when the argument must explicitly mention latency-hidden MULE execution.

## Secondary note
- Peak-window analysis is not required for the core-energy claim in this anchor report.
- If peak results are mentioned at all, they should remain appendix material in the main comparison report rather than part of the core thesis argument here.
- This document should be cited for core power, cycle count, and E/op only.

## Data sources
- outputs/benchmark_power/complex_mul_vec/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/complex_mul_vec/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/complex_mul_vec/metrics/core_2standard.json
- outputs/benchmark_runs/complex_mul_vec/metrics/core_hybrid.json
- outputs/benchmark_power/fft_butterfly/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/fft_butterfly/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/fft_butterfly/metrics/core_2standard.json
- outputs/benchmark_runs/fft_butterfly/metrics/core_hybrid.json
- outputs/benchmark_power/fft_butterfly_latency_hidden_mule/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/fft_butterfly_latency_hidden_mule/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/fft_butterfly_latency_hidden_mule/metrics/core_2standard.json
- outputs/benchmark_runs/fft_butterfly_latency_hidden_mule/metrics/core_hybrid.json
- outputs/benchmark_power/fir_unrolled_latency_hidden_mule/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/fir_unrolled_latency_hidden_mule/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/metrics/core_2standard.json
- outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/metrics/core_hybrid.json

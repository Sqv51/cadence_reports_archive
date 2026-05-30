# Core-Level Energy Anchor Report (2standard vs hybrid)

Date: 2026-05-30
Flow: NanGate45 biriscv_2mul_vs_hybrid

## Scope
This report consolidates the thesis-anchor core-level energy comparison for two selected benchmarks:
- pair_mulmule_overlap (controlled mechanism)
- fir_unrolled_latency_hidden_mule (application-like boundary case)

Power values are from saved Innovus report-only runs.
Cycle and integer-multiply counts are from benchmark metrics JSON outputs.

## Results

### 1) pair_mulmule_overlap
- core_2standard power_total: 10.12674034 mW
- core_hybrid power_total: 9.34486947 mW
- cycles: 155062 vs 155062
- integer multiply ops: 10000 vs 10000
- E/op (pJ): 1570.272611 vs 1449.034150
- hybrid delta: -121.238461 pJ/op (-7.720854%)

Interpretation: With equal cycle count and equal multiply count, hybrid shows a clear net core-energy advantage.

### 2) fir_unrolled_latency_hidden_mule
- core_2standard power_total: 8.71725369 mW
- core_hybrid power_total: 7.82746974 mW
- cycles: 185715 vs 214443
- integer multiply ops: 16128 vs 16128
- E/op (pJ): 1003.797600 vs 1040.765187
- hybrid delta: +36.967587 pJ/op (+3.682773%)

Interpretation: Hybrid reduces average power but increased cycles dominate total energy per multiply operation in this workload/configuration.

## Cross-benchmark takeaways
- Core-level energy savings are workload dependent.
- Hybrid improves E/op strongly when latency-hiding conditions are favorable (pair_mulmule_overlap).
- Hybrid can lose E/op when cycle inflation outweighs power reduction (fir_unrolled_latency_hidden_mule).

## Energy-first thesis framing
- The primary thesis claim should be based on E/op, not peak-window behavior.
- pair_mulmule_overlap is the validated energy-saving case: hybrid cuts core power by 7.720854% with no cycle penalty, so E/op improves by the same 7.720854%.
- fir_unrolled_latency_hidden_mule is the boundary case: hybrid cuts core power by 10.207159%, but cycle count rises by 15.468864%, so E/op worsens by 3.682773%.
- Recommended thesis wording: hybrid saves core energy only when latency hiding prevents the longer MULE latency from increasing total cycles.

## Secondary note
- Peak-window analysis is not required for the core-energy claim in this anchor report.
- If peak results are mentioned at all, they should remain appendix material in the main comparison report rather than part of the core thesis argument here.
- This document should be cited for core power, cycle count, and E/op only.

## Data sources
- outputs/benchmark_power/pair_mulmule_overlap/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/pair_mulmule_overlap/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/pair_mulmule_overlap/metrics/core_2standard.json
- outputs/benchmark_runs/pair_mulmule_overlap/metrics/core_hybrid.json
- outputs/benchmark_power/fir_unrolled_latency_hidden_mule/core_2standard/reports/power_total.rpt
- outputs/benchmark_power/fir_unrolled_latency_hidden_mule/core_hybrid/reports/power_total.rpt
- outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/metrics/core_2standard.json
- outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/metrics/core_hybrid.json

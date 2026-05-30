# 2xMUL vs Hybrid (MUL+MULE) Core Comparison

## 2026-05-30 Status Update (Thesis Anchor)

This section supersedes the older single-testbench interpretation when discussing thesis-level core energy behavior.

### Anchor workloads and validated core energy results

1) pair_mulmule_overlap (controlled mechanism)
- core_2standard power_total: 10.12674034 mW
- core_hybrid power_total: 9.34486947 mW
- cycles: 155062 vs 155062
- integer multiply ops: 10000 vs 10000
- E/op (pJ): 1570.272611 vs 1449.034150
- hybrid delta: -121.238461 pJ/op (-7.720854%)

2) fir_unrolled_latency_hidden_mule (application-like boundary)
- core_2standard power_total: 8.71725369 mW
- core_hybrid power_total: 7.82746974 mW
- cycles: 185715 vs 214443
- integer multiply ops: 16128 vs 16128
- E/op (pJ): 1003.797600 vs 1040.765187
- hybrid delta: +36.967587 pJ/op (+3.682773%)

### Key interpretation for thesis narrative

- Core-level energy savings are workload dependent.
- Hybrid can provide clear E/op savings when latency-hiding conditions are favorable.
- Hybrid can lose E/op when cycle inflation dominates reduced average power.

### Energy-first thesis framing

- The primary thesis claim should use core energy per multiply operation, not peak-window behavior.
- pair_mulmule_overlap is the positive case: hybrid reduces core power by 7.720854% with no cycle penalty, so E/op also improves by 7.720854%.
- fir_unrolled_latency_hidden_mule is the boundary case: hybrid reduces core power by 10.207159%, but cycles increase by 15.468864%, so E/op becomes 3.682773% worse.
- Thesis-safe conclusion: hybrid saves core energy only when latency hiding absorbs the longer MULE latency; lower average power alone is not sufficient.

### Secondary peak appendix status

- Peak-window data below is retained as optional appendix material, not as the main thesis evidence.
- pair_mulmule_overlap peak-window comparison is completed for both configs using refreshed VCD artifacts.
- fir_unrolled_latency_hidden_mule peak-window comparison is completed for both configs using refreshed VCD artifacts.
- VCD dumping in sanitized benchmark testbenches was decoupled from retire-trace verbosity in generate_benchmark_vcds_xrun.py to make reruns more reliable.

### Peak subsection (pair_mulmule_overlap, refresh_clean, finalized)

- Fresh pair benchmark VCD generation completed for both configs in `outputs/benchmark_runs_peak_refresh_clean/pair_mulmule_overlap/vcd/`.
- 1-cycle and 8-cycle window analyses completed (`clock-period-ps=10000`, `skip-initial-cycles=0`).

1-cycle window results (hybrid vs 2standard):
- toggled_bits mean: +3.282905%
- toggled_bits p95: +3.114860%
- toggled_bits p99: +2.805486%
- toggle_events mean: +2.255758%
- toggle_events p95: +1.172529%
- toggle_events p99: +1.694915%

8-cycle window results (hybrid vs 2standard):
- toggled_bits mean: +3.282905%
- toggled_bits p95: +2.959637%
- toggled_bits p99: +0.688054%
- toggle_events mean: +2.255758%
- toggle_events p95: +1.468846%
- toggle_events p99: +1.462735%

Notes:
- With `skip-initial-cycles=0`, startup effects can dominate absolute maxima; percentile and mean deltas are more stable indicators here.
- For final thesis wording on peak suppression, a rerun with nonzero startup skip is recommended and should be applied consistently across both anchor workloads.

### Peak subsection (fir_unrolled_latency_hidden_mule, refresh_clean, finalized)

- Fresh FIR benchmark VCD generation completed for both configs in `outputs/benchmark_runs_peak_refresh_clean/fir_unrolled_latency_hidden_mule/vcd/`.
- 1-cycle and 8-cycle window analyses completed (`clock-period-ps=10000`, `skip-initial-cycles=0`).

1-cycle window results (hybrid vs 2standard):
- toggled_bits mean: +1.847439%
- toggled_bits p95: +5.605889%
- toggled_bits p99: +4.406939%
- toggle_events mean: +0.123188%
- toggle_events p95: +1.092896%
- toggle_events p99: +5.015198%

8-cycle window results (hybrid vs 2standard):
- toggled_bits mean: +1.847953%
- toggled_bits p95: +6.050483%
- toggled_bits p99: +8.772659%
- toggle_events mean: +0.123694%
- toggle_events p95: +3.490627%
- toggle_events p99: +9.351032%

Notes:
- In this raw `skip-initial-cycles=0` view, hybrid does not show peak-window suppression for FIR; upper-percentile switching is modestly higher than 2standard even though average core power is lower.
- As with the pair benchmark, a nonzero startup skip should be used before making any stronger peak-suppression claim in final thesis text.

### Source package

- Detailed report: outputs/summary/core_energy_anchor_report_20260530.md
- CSV table: outputs/summary/core_energy_anchor_report_20260530.csv
- Peak windows CSVs (pair): outputs/summary/peak_windows_pair_mulmule_overlap/w1/ and outputs/summary/peak_windows_pair_mulmule_overlap/w8/
- Peak windows CSVs (fir): outputs/summary/peak_windows_fir_unrolled_latency_hidden_mule/w1/ and outputs/summary/peak_windows_fir_unrolled_latency_hidden_mule/w8/
- Archive copy: /home/ykaraagac/cadence_reports_archive/biriscv_2alts_final_reports/20260530_mul_mule_1p5ghz_corrected/

Date: 2026-03-24
Node: NanGate45 (45 nm)
Design: biRISC-V dual-issue core (`riscv_core`)
Clock target: 100 MHz (`Tclk = 10 ns`)
Workload: `tb_mul_compare` — 1000 iterations, each performing two multiply operations with random operands

## Configurations

| | Config A: **2xMUL** | Config B: **Hybrid** |
|---|---|---|
| Pipe A multiplier | Booth-Wallace (`u_mul`) | Booth-Wallace (`u_mul`) |
| Pipe B multiplier | Booth-Wallace (`u_mul2`) | Iterative-efficient (`u_mule`) |
| RTL branch | `2-standard` | `2-alts` |
| MUL latency | 3 cycles | 3 cycles |
| Pipe B mul latency | 3+1=4 cycles (stagger) | 5 cycles |

## Source Reports

| Data | 2xMUL | Hybrid |
|---|---|---|
| Simulation log | `logs/xrun_core_2standard.log` | `logs/xrun_core_hybrid.log` |
| Synthesis area | `outputs/genus/core_2standard/syn_rpt/final_area.rpt` | `outputs/genus/core_hybrid/syn_rpt/final_area.rpt` |
| Timing QoR | `outputs/innovus/core_2standard/vcd/reports/um/flow_QOR_summary.rpt` | `outputs/innovus/core_hybrid/vcd/reports/um/flow_QOR_summary.rpt` |
| VCD core power | `outputs/innovus/core_2standard/vcd/reports/power_total.rpt` | `outputs/innovus/core_hybrid/vcd/reports/power_total.rpt` |
| u_mul power | `outputs/innovus/core_2standard/vcd/reports/power_inst_a.rpt` | `outputs/innovus/core_hybrid/vcd/reports/power_inst_a.rpt` |
| Pipe B mul power | `outputs/innovus/core_2standard/vcd/reports/power_inst_b.rpt` (u_mul2) | `outputs/innovus/core_hybrid/vcd/reports/power_inst_b.rpt` (u_mule) |

## Raw Measured Numbers

### 1) Functional Verification & Latency (from xrun)

| Metric | 2xMUL | Hybrid |
|---|---|---|
| Compare result | **PASSED** (1000/1000) | **PASSED** (1000/1000) |
| MUL (u_mul) avg latency | 3 cycles | 3 cycles |
| MULE completions | 0 (not used) | 1000, avg 5 cycles |
| End-of-test cycle (PC=PASS) | 32035 | 34036 |
| Measured cycles/iteration | ~32 | ~34 |

**Important observation**: In the 2xMUL configuration, `u_mul2` was **never used** — MULE completions = 0. Both `mul` instructions were decoded as standard MUL (since `mule_o = 1'b0` in 2-standard decoder) and executed sequentially through `u_mul`. The second MUL unit is present but not exercised by this workload because the issue logic requires the custom MULE opcode to route to pipe B.

### 2) Core Power (VCD-based, post-route Innovus/Voltus)

| Metric | 2xMUL | Hybrid | Delta |
|---|---|---|---|
| Total core power | **8.295 mW** | **8.270 mW** | Hybrid −0.30% |
| Internal power | 4.532 mW | 4.430 mW | |
| Switching power | 2.532 mW | 2.650 mW | |
| Leakage power | 1.230 mW | 1.190 mW | |
| Clock power | 1.454 mW | 1.459 mW | |

### 3) Area (Genus synthesis)

| Metric | 2xMUL | Hybrid | Delta |
|---|---|---|---|
| Total cell area | **62640.9 um²** | **61009.5 um²** | Hybrid −2.67% |
| Cell count | 29153 | 28302 | |
| u_mul area | 4515.9 um² | 4515.9 um² | same |
| Pipe B mul area | 4515.9 um² (u_mul2) | 2133.9 um² (u_mule) | Hybrid −52.7% |

### 4) Timing QoR (Innovus post-route)

| Metric | 2xMUL | Hybrid |
|---|---|---|
| Final WNS (ALL) | +5.195 ns | +5.252 ns |
| TNS | 0 | 0 |
| DRVs (Tran/Cap) | 0 / 0 | 0 / 2 |
| Density | 70.37% | 70.36% |

Both designs close timing comfortably at 100 MHz with >5 ns positive slack.

### 5) Multiplier Subsystem Power (instance reports)

| Instance | 2xMUL | Hybrid |
|---|---|---|
| `u_mul` (Booth-Wallace) | **2.020 mW** (24.35%) | **1.188 mW** (14.36%) |
| Pipe B multiplier | **1.017 mW** (`u_mul2`, 12.27%) | **0.155 mW** (`u_mule`, 1.87%) |
| **Multiplier total** | **3.037 mW** (36.6% of core) | **1.343 mW** (16.2% of core) |

Hybrid's multiplier subsystem consumes **55.8% less** power than 2xMUL's, but the rest of the core absorbs the difference—total core power differs by only 0.30%.

## Derived Metrics

### Method A: Workload-Level (measured end-to-end)

Uses actual measured total cycles from simulation (32035 vs 34036 for 1000 iterations × 2 ops = 2000 multiply ops). This includes all loop overhead (ALU, branch, memory operations).

| Metric | 2xMUL | Hybrid | Ratio |
|---|---|---|---|
| Total cycles | 32035 | 34036 | |
| Throughput | **6.24 Mops/s** | **5.88 Mops/s** | 2xMUL **1.06x** faster |
| Energy per op | **1328.6 pJ** | **1407.4 pJ** | 2xMUL **5.6%** better |
| EDP (workload) | **8.513e-10 J·s** | **9.580e-10 J·s** | Hybrid **12.5%** worse |

### Method B: Multiplier-Only (theoretical peak)

Isolates just the multiply instruction throughput using raw latency (ignores loop overhead). Represents the best-case scenario if the workload were 100% multiply-bound.

| Metric | 2xMUL | Hybrid | Ratio |
|---|---|---|---|
| Iteration latency | 3 cycles (MUL) | 5 cycles (MULE) | |
| Peak throughput | **66.67 Mops/s** | **40.00 Mops/s** | 2xMUL **1.67x** faster |
| Peak energy/op | **124.4 pJ** | **206.7 pJ** | 2xMUL **1.66x** better |
| Peak EDP/iter | **7.465e-18 J·s** | **2.067e-17 J·s** | Hybrid **2.77x** worse |

**Note**: Method B is theoretical — the actual workload (Method A) shows the difference is much smaller because multiply instructions are only a fraction of total execution. Method A reflects the realistic comparison.

## Summary Comparison Table

| Metric | Winner | Margin |
|---|---|---|
| **Total core power** | Hybrid | −0.30% |
| **Multiplier subsystem power** | **Hybrid** | **−55.8%** |
| **Area** | **Hybrid** | **−2.67%** |
| **Throughput (measured workload)** | 2xMUL | +6.2% |
| **Energy/op (measured workload)** | 2xMUL | +5.6% |
| **EDP (measured workload)** | 2xMUL | +12.5% |
| **Timing slack** | Comparable | 5.2 vs 5.3 ns |

## Conclusion

For the `tb_mul_compare` workload on NanGate45 at 100 MHz:

1. **2xMUL wins on throughput/EDP** by a modest 6–12% margin, because it executes each multiply-pair iteration in ~32 cycles vs ~34 for Hybrid.

2. **Hybrid wins decisively on multiplier power** (−55.8%) and **area** (−2.67%), meaning the Hybrid approach trades a small throughput penalty for substantial hardware savings.

3. **Total core power is nearly identical** (0.30% difference), because the multiplier subsystem is a minority of total core power — the pipeline, register file, branch predictor, and control logic dominate.

4. **2xMUL's second multiplier (`u_mul2`) was never actually used** in this test because the binary does not contain the custom MULE opcode needed to route to pipe B. Both standard `mul` instructions execute sequentially through `u_mul`. A workload that dual-issues standard MUL + MULE custom instructions would show a different balance.

5. **For area-constrained or power-budgeted designs**, the Hybrid configuration is the better trade-off: it achieves nearly identical total power and throughput while saving 2382 um² of silicon area (one full Booth-Wallace multiplier replaced by a 52.7% smaller iterative unit).

## Notes

- All power numbers are VCD-based post-route (Innovus/Voltus) with ~10–11% VCD annotation coverage.
- The remaining ~89% of nets use default switching activity (0.2).
- A workload with higher multiply instruction density would amplify the throughput difference.
- A workload with sparser multiplications would further favor Hybrid due to lower leakage from the smaller `u_mule`.

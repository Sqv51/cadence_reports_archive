# 2xMUL vs Hybrid (MUL+MULE) Core Comparison

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

## Generalized Formulas (Items 1 and 2)

Definitions:

- Fast path (e.g., MUL): latency `L_f` (cycles), energy/op `e_f` (J/op)
- Efficient path (e.g., MULE): latency `L_e` (cycles), energy/op `e_e` (J/op)
- Extra latency of efficient path: `ΔL = L_e - L_f >= 0`
- Production-consumption distance for one use site: `D` (cycles of independent work before first consume)
- Exposed stall cycles for one operation:
	`s(D) = max(0, ΔL - D)`
- Hidden latency for one operation:
	`h(D) = min(ΔL, D)`
- Energy cost per exposed extra cycle (workload-dependent): `e_cyc` (J/cycle)
- Number of converted operations: `N`

### 1) Energy Saving When Extra Latency Is Fully Absorbed

Full absorption condition:

`D >= ΔL`  for each converted operation, equivalently `s(D)=0`.

Then total energy saving from converting `N` operations is:

`ΔE_full = N * (e_f - e_e)`

Relative saving (per converted op):

`η_full = (e_f - e_e) / e_f = 1 - e_e/e_f`

If only a fraction `ρ` of all candidate operations is converted and fully absorbed:

`ΔE_full = ρ * N_total * (e_f - e_e)`

Interpretation: when all extra latency is hidden, energy benefit depends only on per-op energy difference, not on latency.

### 2) General Energy-Latency Tradeoff vs Production-Consumption Distance

For a single operation with distance `D`:

- Exposed latency penalty: `s(D) = max(0, ΔL - D)` cycles
- Net energy saving:
	`Δe_net(D) = (e_f - e_e) - s(D) * e_cyc`

Break-even condition (beneficial conversion):

`Δe_net(D) > 0  <=>  (e_f - e_e) > s(D) * e_cyc`

Equivalent minimum distance for break-even:

`D >= ΔL - (e_f - e_e)/e_cyc`

For a program with distance distribution `P(D=d)`:

- Expected exposed stall per converted op:
	`E[s] = Σ_d max(0, ΔL - d) * P(D=d)`
- Expected net energy saving per converted op:
	`E[Δe_net] = (e_f - e_e) - e_cyc * E[s]`

For `N` converted operations:

- Total energy delta:
	`ΔE = N * E[Δe_net]`
- Total extra cycles:
	`ΔC = N * E[s]`
- Total latency increase:
	`ΔT = ΔC * Tclk`

Compact EDP tradeoff with baseline `(E0, T0)`:

- `E1 = E0 - ΔE`
- `T1 = T0 + ΔT`
- `EDP_ratio = (E1*T1)/(E0*T0)`

`EDP_ratio < 1` means the efficient path is better overall.

## Item 6: Leakage Difference at Lower Technology Nodes (Easiest)

This study is at 45 nm, where dynamic power dominates and leakage is a smaller fraction of total power.

At lower nodes (7 nm / 5 nm / 3 nm), leakage fraction generally increases, so area reductions have stronger total-power impact.

First-order model:

- Let leakage fraction be `lambda = P_leak / P_total`
- Let total area reduction be `alpha = DeltaA / A`

Then approximate total-power reduction from leakage scaling alone is:

`DeltaP_total/P_total ~= lambda * alpha`

Using measured `alpha = 2.67%`:

- If `lambda = 15%` (older node behavior): `~0.40%` total-power reduction
- If `lambda = 50%` (advanced-node behavior): `~1.34%` total-power reduction

So, the Hybrid design's area advantage should become more valuable as node scales down, especially in leakage-sensitive or thermally constrained operating points.

## Item 4: Potential Energy Savings if Latency Is Fully Hidden in General Programs

From Method A measurements:

- Core energy/op gap (Hybrid - 2xMUL): `+78.8 pJ/op`
- Extra cycles/op observed: `~1.0005 cycles/op`
- Core energy/cycle at 100 MHz: `~82.7 pJ/cycle`

Estimated hidden-latency energy benefit per operation:

`Deltae_hidden ~= 78.8 - 82.7*1.0005 ~= -3.95 pJ/op (Hybrid better)`

Magnitude of potential savings when latency is fully hidden:

`~3.95 pJ/op` at current power point (about `0.30%` of 2xMUL energy/op).

Equivalent per converted multiply (roughly half of ops in this workload map to the efficient path):

`~7.9 pJ per converted multiply`

Program-level estimate when only fully-hidden opportunities are converted:

- If `N_hide` multiplies are converted with full absorption:
	`DeltaE_program ~= N_hide * 7.9 pJ`

This gives a direct estimator for compiler/scheduler-guided conversion policies.

## Item 7: Parallelized Deployment Comparison (Hybrid vs 2-standard)

### A) Fixed core count (`K` cores each design)

- Throughput scales approximately linearly with `K` for both
- Latency for a fixed job scales as `1/K` for both
- Relative single-core ratio is preserved

Using measured single-core ratios:

- Throughput ratio (Hybrid/2xMUL): `5.88/6.24 = 0.942`
- Energy/op ratio (Hybrid/2xMUL): `1407.4/1328.6 = 1.059`
- EDP ratio (Hybrid/2xMUL): `1.125`

So at equal core count, parallelization does not change the ranking: 2xMUL remains better in throughput, EPI, and EDP for this workload.

### B) Fixed silicon area budget

Hybrid core area is 2.67% smaller, so feasible core count gain is:

`K_hybrid/K_2xMUL ~= 1/0.9733 = 1.027`

Effective throughput ratio under equal area budget:

`(Hybrid/2xMUL)_throughput ~= 0.942 * 1.027 = 0.967`

So Hybrid remains about `3.3%` slower in latency/throughput under fixed-area scaling for this workload.

Approximate EDP ratio under fixed area:

`EDP_ratio_area ~= 1.059 * 1.034 ~= 1.094`

Hybrid still trails by about `9.4%` EDP in this measured workload, but the gap narrows versus fixed-core deployment.

## Items 3 and 5: Trace-Based Benchmark Energy Analysis

Energy analysis using `energy_benchmark_analysis.py` on 5 Spike ISA kernel traces with Cadence NanGate45 post-route power data.

Energy parameters (hybrid dual-core config):

| Parameter | Value | Source |
|---|---|---|
| `P_mul` (Booth avg) | 2.020 mW | power_inst_a.rpt (2xMUL cfg) |
| `P_mule` (MULE avg) | 0.155 mW | power_inst_b.rpt (Hybrid cfg) |
| `L_mul` / `L_mule` | 3 / 5 cycles | RTL simulation |
| `ΔL` | 2 cycles | |
| `e_mul` / `e_mule` | 60.60 / 7.75 pJ | P × L × Tclk |
| `Δe` | 52.85 pJ/op | saving at zero stall |
| `e_cyc` | 82.70 pJ | core energy per cycle |

Break-even: `D ≥ 2` (one exposed stall destroys the saving since `e_cyc > Δe`)

### Per-Kernel Results (ΔL=2)

| Kernel | Insns | MUL ops | MUL% | D distribution | FH% (D≥2) | PH% (D<2) |
|---|---:|---:|---:|---|---:|---:|
| dotprod | 9,219 | 1,024 | 11.1% | D=1: 1024 | 0% | 100% |
| FIR filter | 112,896 | 16,128 | 14.3% | D=1: 16128 | 0% | 100% |
| Horner eval | 12,288 | 2,048 | 16.7% | D=1: 2048 | 0% | 100% |
| Matrix mul | 268,384 | 32,768 | 12.2% | D=2: 32768 | 100% | 0% |
| Unrolled dot | 19,456 | 4,096 | 21.1% | D=2:1024, D=3:2048, D=4:1024 | 100% | 0% |

### Cross-Benchmark Energy Summary (ΔL=2)

| Kernel | Net ALL (pJ) | ALL %core | Net FH-only (pJ) | FH %core | PH per-op |
|---|---:|---:|---:|---:|---:|
| dotprod | −30,566 | −4.0% | 0 | 0% | −29.85 pJ |
| FIR | −481,421 | −5.2% | 0 | 0% | −29.85 pJ |
| Horner | −61,133 | −6.0% | 0 | 0% | −29.85 pJ |
| matmul | **+1,731,789** | **+7.8%** | **+1,731,789** | **+7.8%** | n/a |
| unrolled_dot | **+216,474** | **+13.5%** | **+216,474** | **+13.5%** | n/a |

### Key Findings

1. **Sharp binary split**: Kernels divide cleanly into D=1 (accumulate-after-multiply, net loss) and D≥2 (independent accumulate, full benefit).

2. **matmul and unrolled_dot achieve +7.8% and +13.5% core energy savings** — all MUL ops have D≥2, so every conversion saves the full 52.85 pJ/op with zero stall.

3. **dot/FIR/Horner show net energy loss** — all ops at D=1 expose 1 stall cycle, costing 82.7 pJ but saving only 52.85 pJ (net −29.85 pJ/op).

4. **Selective conversion is essential** — converting only fully-hidden ops in matmul/unrolled_dot captures all benefit; converting D=1 ops always loses energy.

5. **Scheduling opportunity**: Kernels with D=1 (accumulate chains) could potentially benefit from loop unrolling or software pipelining to increase D above the threshold.

## Next Analysis TODO

1. Completed: generalized formula for energy saving while fully absorbing latency (see section above).
2. Completed: generalized formula for energy-latency tradeoff vs production-consumption distance and path difference (see section above).
4. Completed (trace-based): energy savings from fully-hidden-only conversion on 5 kernel benchmarks.
5. Completed (trace-based): energy savings calculation on real kernel traces (dot, FIR, Horner, matmul, unrolled_dot).
6. Completed: leakage-difference acknowledgement and scaling model for lower-nm technologies.
7. Completed: parallelized deployment comparison (fixed-core and fixed-area) for EDP, EPI, and latency.

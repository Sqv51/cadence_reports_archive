# Consolidated MUL vs MULE Energy-Delay Analysis

**Technology:** NanGate45 (45 nm, 1.1 V)
**Clock:** 100 MHz (T_clk = 10 ns)
**Design:** biRISC-V dual-issue RISC-V core (`riscv_core`)
**Tool Flow:** RTL → Xcelium 25.09 (VCD) → Genus DDI 25.1 (synthesis) → Innovus DDI 25.1 (P&R + Voltus power)
**Date:** 2026-03-24

---

## Table of Contents

1. [Multiplier Architectures](#1-multiplier-architectures)
2. [Data Sources](#2-data-sources)
3. [Standalone Multiplier Measurements](#3-standalone-multiplier-measurements)
4. [In-Core Instance Measurements](#4-in-core-instance-measurements)
5. [EPI — Energy Per Instruction](#5-epi--energy-per-instruction)
6. [EPI Without Leakage](#6-epi-without-leakage)
7. [EDP — Energy-Delay Product](#7-edp--energy-delay-product)
8. [Hybrid vs 2×MUL Core Comparison](#8-hybrid-vs-2mul-core-comparison)
9. [Generalized Formulas](#9-generalized-formulas)
10. [Benchmark Trace Energy Analysis](#10-benchmark-trace-energy-analysis)

---

## 1. Multiplier Architectures

### MUL — Single-Cycle Combinational (biriscv_multiplier)

- 33×33 signed combinational multiply (Verilog `*` operator; Genus maps to library multiplier)
- 2-stage fixed-latency pipeline: E1 (latch operands + combinational multiply), E2 (register result)
- **Latency:** 2 cycles (standalone module, `MULT_STAGES=2`), 3 cycles (issue-to-writeback in core pipeline, confirmed by simulation log)
- Critical path (Genus): 4.606 ns (53% slack at 100 MHz)
- Note: With `SUPPORT_MUL_BYPASS=1` (default), a dependent instruction can issue 1 cycle before writeback via E2-stage bypass

### MULE — Iterative Efficient (biriscv_multiplier_efficient)

- 16×16 unsigned sub-multiplier reused 3× via FSM
- Supports only lower-32-bit `MUL` result (no `MULH`/`MULHSU`/`MULHU`); accessed via custom `mule` opcode
- 5-state FSM: IDLE → CALC0 → CALC1 → CALC2 → DONE
- CALC0: P0 = A_low × B_low; CALC1: P1 = A_low × B_high; CALC2: P2 = A_high × B_low
- DONE: result = P0 + (P1 << 16) + (P2 << 16)
- **Latency:** 5 cycles
- Critical path (Genus): 2.996 ns (69% slack at 100 MHz)

---

## 2. Data Sources

All data cited in this report comes from the following Cadence tool output files archived under `cadence_reports_archive/20260324/NanGate45/`.

### 2.1 Standalone MUL/MULE Power Flow (`biriscv_mul_mule_power/`)

| Data | File Path |
|---|---|
| MUL standalone power (VCD) | `innovus/mul_standalone/vcd/reports/power_total.rpt` |
| MULE standalone power (VCD) | `innovus/mule_standalone/vcd/reports/power_total.rpt` |
| Core total power (VCD) | `innovus/core_scope/vcd/reports/power_total.rpt` |
| u_mul in-core instance power | `innovus/core_scope/vcd/reports/power_inst_a.rpt` |
| u_mule in-core instance power | `innovus/core_scope/vcd/reports/power_inst_b.rpt` |
| MUL standalone area | `genus/mul_standalone/syn_rpt/final_area.rpt` |
| MULE standalone area | `genus/mule_standalone/syn_rpt/final_area.rpt` |
| Core area (Hybrid config) | `genus/core_scope/syn_rpt/final_area.rpt` |

### 2.2 Dual-Core 2×MUL vs Hybrid Flow (`biriscv_2mul_vs_hybrid/`)

| Data | 2×MUL | Hybrid |
|---|---|---|
| Core power (VCD) | `innovus/core_2standard_vcd/power_total.rpt` | `innovus/core_hybrid_vcd/power_total.rpt` |
| u_mul instance power | `innovus/core_2standard_vcd/power_inst_a.rpt` | `innovus/core_hybrid_vcd/power_inst_a.rpt` |
| Pipe B mul instance power | `innovus/core_2standard_vcd/power_inst_b.rpt` (u_mul2) | `innovus/core_hybrid_vcd/power_inst_b.rpt` (u_mule) |
| Synthesis area | `genus/core_2standard/final_area.rpt` | `genus/core_hybrid/final_area.rpt` |
| Timing QoR | `innovus/core_2standard_vcd/flow_QOR_summary.rpt` | `innovus/core_hybrid_vcd/flow_QOR_summary.rpt` |
| Simulation log | `logs/xrun_core_2standard.log` | `logs/xrun_core_hybrid.log` |

### 2.3 Benchmark Trace Analysis (`riscv_dependency_analysis/`)

| Data | File Path |
|---|---|
| Analysis script | `energy_benchmark_analysis.py` |
| Hybrid params results (ΔL=2) | `energy_analysis_hybrid.txt` |
| Standalone params results (ΔL=3) | `energy_analysis_standalone.txt` |
| Dependency analysis script | `mul_centric_analysis.py` |
| Kernel traces (Spike ISA sim) | `kernel_dot.log`, `kernel_fir.log`, `kernel_horner.log`, `kernel_matmul.log`, `kernel_unrolled.log` |

### 2.4 Tool Versions & Methodology

| Tool | Version | Purpose |
|---|---|---|
| Cadence Xcelium | 25.09-s003 | RTL simulation + VCD generation |
| Cadence Genus | DDI 25.1 (25.12-s067_1) | Logic synthesis |
| Cadence Innovus | DDI 25.1 | Place & route + Voltus power analysis |
| RISC-V Spike | — | ISA-level trace generation for benchmarks |
| PDK | NangateOpenCellLibrary rev 1.0 | 45 nm standard cells |

**Power methodology:** VCD-based post-route (Innovus/Voltus). VCD annotation coverage: ~10–11% of total nets (~18% of flop outputs). Remaining nets use default switching activity (0.2). All numbers are worst-case view (WC_VIEW) at 1.1 V, 100 MHz.

---

## 3. Standalone Multiplier Measurements

Measured from individually synthesized and placed-&-routed multiplier modules exercised with identical testbench stimuli.

### 3.1 Power Breakdown

| Metric | MUL | MULE | Δ |
|---|---|---|---|
| Internal Power | 0.6515 mW | 0.1383 mW | −78.8% |
| Switching Power | 0.5601 mW | 0.0878 mW | −84.3% |
| Leakage Power | 0.0895 mW | 0.0392 mW | −56.2% |
| **Total Power** | **1.301 mW** | **0.265 mW** | **−79.6%** |

*Source: `power_total.rpt` from `mul_standalone/vcd/` and `mule_standalone/vcd/`*

### 3.2 Dynamic Power (Without Leakage)

| Metric | MUL | MULE | Δ |
|---|---|---|---|
| Dynamic Power (Int + Sw) | 1.2116 mW | 0.2261 mW | −81.3% |
| Leakage fraction | 6.88% | 14.77% | — |

### 3.3 Area

| Metric | MUL | MULE | Δ |
|---|---|---|---|
| Cell Count | 2302 | 822 | −64.3% |
| Cell Area | 4514.6 µm² | 2135.4 µm² | −52.7% |

*Source: `final_area.rpt` from `mul_standalone/` and `mule_standalone/`*

---

## 4. In-Core Instance Measurements

Measured from `riscv_core` netlist (Hybrid configuration) with VCD from `tb_mul_compare` workload. Both instances measured in the **same simulation**, same core.

### 4.1 Power Breakdown

| Metric | u_mul | u_mule | Δ |
|---|---|---|---|
| Internal Power | 0.5954 mW | 0.0871 mW | −85.4% |
| Switching Power | 0.4663 mW | 0.0280 mW | −94.0% |
| Leakage Power | 0.1263 mW | 0.0399 mW | −68.4% |
| **Total Power** | **1.188 mW** | **0.155 mW** | **−87.0%** |
| % of Core (8.270 mW) | 14.36% | 1.87% | — |

*Source: `power_inst_a.rpt` (u_mul) and `power_inst_b.rpt` (u_mule) from `core_scope/vcd/`*

### 4.2 Dynamic Power (Without Leakage)

| Metric | u_mul | u_mule | Δ |
|---|---|---|---|
| Dynamic Power (Int + Sw) | 1.0617 mW | 0.1151 mW | −89.2% |
| Leakage fraction | 10.63% | 25.74% | — |

### 4.3 Core-Level Power

| Metric | Value |
|---|---|
| Core Total Power | 8.270 mW |
| Core Internal Power | 4.430 mW |
| Core Switching Power | 2.650 mW |
| Core Leakage Power | 1.190 mW (14.39%) |
| Core Dynamic Power (no leakage) | 7.080 mW |

*Source: `power_total.rpt` from `core_scope/vcd/`*

### 4.4 Area (In-Core)

| Instance | Cell Count | Cell Area |
|---|---|---|
| u_mul | 2303 | 4515.9 µm² |
| u_mule | 820 | 2133.9 µm² (−52.7%) |
| riscv_core (Hybrid) | 28302 | 61009.5 µm² |

*Source: `final_area.rpt` from `core_scope/`*

---

## 5. EPI — Energy Per Instruction

$$EPI = P_{avg} \times N_{cycles} \times T_{clk}$$

### 5.1 Standalone EPI

| | MUL | MULE | Δ |
|---|---|---|---|
| P_avg | 1.301 mW | 0.265 mW | |
| Cycles | 2 | 5 | |
| **EPI** | **26.02 pJ** | **13.25 pJ** | **−49.1%** |

### 5.2 In-Core EPI

| | u_mul | u_mule | Δ |
|---|---|---|---|
| P_avg | 1.188 mW | 0.155 mW | |
| Cycles | 2 | 5 | |
| **EPI** | **23.76 pJ** | **7.75 pJ** | **−67.4%** |

---

## 6. EPI Without Leakage

Leakage power is a static, always-on component that does not scale with switching activity. Removing it isolates the energy that is directly caused by executing the multiply operation.

$$EPI_{dynamic} = P_{dynamic} \times N_{cycles} \times T_{clk}$$

where $P_{dynamic} = P_{internal} + P_{switching}$ (excludes $P_{leakage}$).

### 6.1 Standalone EPI (Leakage-Free)

| | MUL | MULE | Δ |
|---|---|---|---|
| P_dynamic | 1.2116 mW | 0.2261 mW | −81.3% |
| P_leakage (excluded) | 0.0895 mW | 0.0392 mW | |
| Cycles | 2 | 5 | |
| **EPI_dynamic** | **24.23 pJ** | **11.31 pJ** | **−53.3%** |

Compared to total EPI: MUL drops from 26.02 → 24.23 pJ (−6.9%), MULE drops from 13.25 → 11.31 pJ (−14.6%). MULE's leakage accounts for a larger fraction of its total because dynamic power is so low.

### 6.2 In-Core EPI (Leakage-Free)

| | u_mul | u_mule | Δ |
|---|---|---|---|
| P_dynamic | 1.0617 mW | 0.1151 mW | −89.2% |
| P_leakage (excluded) | 0.1263 mW | 0.0399 mW | |
| Cycles | 2 | 5 | |
| **EPI_dynamic** | **21.23 pJ** | **5.76 pJ** | **−72.9%** |

Compared to total in-core EPI: MUL drops from 23.76 → 21.23 pJ (−10.6%), MULE drops from 7.75 → 5.76 pJ (−25.7%).

### 6.3 Summary: EPI With vs Without Leakage

| Metric | MUL | MULE | MULE reduction |
|---|---|---|---|
| **Standalone EPI (total)** | 26.02 pJ | 13.25 pJ | −49.1% |
| **Standalone EPI (dynamic)** | 24.23 pJ | 11.31 pJ | −53.3% |
| **In-core EPI (total)** | 23.76 pJ | 7.75 pJ | −67.4% |
| **In-core EPI (dynamic)** | 21.23 pJ | 5.76 pJ | −72.9% |

Key observation: Excluding leakage widens MULE's advantage because leakage is a larger fraction of MULE's total power (14.8% standalone, 25.7% in-core) than of MUL's (6.9% standalone, 10.6% in-core). In workloads where multiplies are infrequent and the unit is mostly idle, leakage dominates — and MULE still wins because it has 52.7% less area (and thus less leakage).

---

## 7. EDP — Energy-Delay Product

$$EDP = EPI \times T_{latency} = EPI \times N_{cycles} \times T_{clk}$$

### 7.1 With Leakage

| | MUL | MULE | Δ |
|---|---|---|---|
| Standalone EDP | 520.4 aJ·s | 662.5 aJ·s | MULE 27.3% worse |
| **In-core EDP** | **475.2 aJ·s** | **387.3 aJ·s** | **MULE 18.5% better** |

### 7.2 Without Leakage

| | MUL | MULE | Δ |
|---|---|---|---|
| Standalone EDP_dyn | 484.6 aJ·s | 565.5 aJ·s | MULE 16.7% worse |
| **In-core EDP_dyn** | **424.6 aJ·s** | **288.0 aJ·s** | **MULE 32.2% better** |

Calculation (in-core, leakage-free):
- MUL: 21.23 pJ × 20 ns = 424.6 aJ·s
- MULE: 5.76 pJ × 50 ns = 288.0 aJ·s

### 7.3 EDP Summary

| EDP variant | MUL | MULE | Winner | Margin |
|---|---|---|---|---|
| Standalone (total) | 520.4 aJ·s | 662.5 aJ·s | MUL | 27.3% |
| Standalone (dynamic) | 484.6 aJ·s | 565.5 aJ·s | MUL | 16.7% |
| In-core (total) | 475.2 aJ·s | 387.3 aJ·s | **MULE** | **18.5%** |
| In-core (dynamic) | 424.6 aJ·s | 288.0 aJ·s | **MULE** | **32.2%** |

MULE wins EDP in-core because the real workload allows effective power gating when idle (switching power drops 94%). Standalone benchmarks exercise the unit back-to-back, masking this advantage.

---

## 8. Hybrid vs 2×MUL Core Comparison

### 8.1 Configurations

| | 2×MUL | Hybrid (MUL+MULE) |
|---|---|---|
| Pipe A multiplier | Combinational (`u_mul`) | Combinational (`u_mul`) |
| Pipe B multiplier | Combinational (`u_mul2`) | Iterative (`u_mule`) |
| RTL branch | `2-standard` | `2-alts` |
| Pipe A MUL latency | 3 cycles | 3 cycles |
| Pipe B mul latency | 3+1=4 cycles (stagger, theoretical — u_mul2 never exercised) | 5 cycles |

**Note:** Hybrid core power data is from the same simulation/VCD as Section 4 (same design, same workload, same VCD annotation: 11.1% total nets, 18.3% flop outputs).

### 8.2 Measured Core Power

| Metric | 2×MUL | Hybrid | Δ |
|---|---|---|---|
| Internal Power | 4.532 mW | 4.430 mW | −2.3% |
| Switching Power | 2.532 mW | 2.650 mW | +4.7% |
| Leakage Power | 1.230 mW | 1.190 mW | −3.3% |
| **Total Core Power** | **8.295 mW** | **8.270 mW** | **−0.30%** |

*Source: `power_total.rpt` from `core_2standard_vcd/` and `core_hybrid_vcd/`*

### 8.3 Multiplier Instance Power

| Instance | 2×MUL | Hybrid |
|---|---|---|
| u_mul (Int / Sw / Leak) | 0.993 / 0.855 / 0.172 mW | 0.595 / 0.466 / 0.126 mW |
| u_mul **total** | **2.020 mW** (24.35%) | **1.188 mW** (14.36%) |
| Pipe B mul (Int / Sw / Leak) | 0.500 / 0.431 / 0.086 mW | 0.087 / 0.028 / 0.040 mW |
| Pipe B mul **total** | **1.017 mW** (12.27%) | **0.155 mW** (1.87%) |
| **Multiplier total** | **3.037 mW** (36.6%) | **1.343 mW** (16.2%) |
| Multiplier dynamic (no leak) | 2.779 mW | 1.176 mW (−57.7%) |

*Source: `power_inst_a.rpt` and `power_inst_b.rpt` from each config's VCD directory*

### 8.4 Area

| Metric | 2×MUL | Hybrid | Δ |
|---|---|---|---|
| u_mul area | 4515.9 µm² | 4515.9 µm² | same |
| Pipe B mul area | 4515.9 µm² | 2133.9 µm² | −52.7% |
| Cell count | 29153 | 28302 | −2.9% |
| **Total core area** | **62640.9 µm²** | **61009.5 µm²** | **−2.6%** |

*Source: `final_area.rpt` from `core_2standard/` and `core_hybrid/`*

### 8.5 Timing QoR

| Metric | 2×MUL | Hybrid |
|---|---|---|
| Final WNS | +5.195 ns | +5.252 ns |
| TNS | 0 | 0 |
| DRVs (Tran/Cap) | 0 / 0 | 0 / 2 |
| Density | 70.37% | 70.36% |

Both close timing comfortably at 100 MHz with >5 ns positive slack.

*Source: `flow_QOR_summary.rpt` from each VCD directory*

### 8.6 Workload-Level Metrics (Measured Simulation)

Workload: `tb_mul_compare` — 1000 iterations, 2 multiply ops each (2000 total).

| Metric | 2×MUL | Hybrid | Ratio |
|---|---|---|---|
| Total cycles | 32035 | 34036 | |
| Throughput | 6.24 Mops/s | 5.88 Mops/s | 2×MUL 1.06× faster |
| Energy per op | 1328.6 pJ | 1407.4 pJ | 2×MUL 5.6% better |
| EDP (workload) | 8.513×10⁻¹⁰ J·s | 9.580×10⁻¹⁰ J·s | 2×MUL 12.5% better |

**Critical caveat:** In the 2×MUL configuration, `u_mul2` was **never exercised** — the binary uses standard `mul` opcodes, and the issue logic requires the custom `mule` opcode to route to pipe B. Both multiplies executed sequentially through `u_mul`. Therefore the workload-level comparison does not represent true dual-issue multiply throughput.

### 8.7 Theoretical Dual-Issue Comparison

Since the testbench did not properly exercise both multipliers in parallel, we compute the theoretical case where both pipes execute multiplies simultaneously.

**Assumptions:**
- Workload issues MUL pairs: one to pipe A, one to pipe B, every iteration
- Iteration latency = max(pipe A latency, pipe B latency)
- Core power as measured (includes both multipliers active or idle-gated)

| Metric | 2×MUL (theoretical) | Hybrid (theoretical) |
|---|---|---|
| Pipe A latency | 3 cycles | 3 cycles |
| Pipe B latency | 4 cycles (3+1 stagger) | 5 cycles |
| Iteration latency | 4 cycles | 5 cycles |
| Pair throughput | 50.0 Mpairs/s | 40.0 Mpairs/s |
| Per-pair energy | P_core × L × T_clk | P_core × L × T_clk |
| | 8.295 × 4 × 10 = 331.8 pJ | 8.270 × 5 × 10 = 413.5 pJ |
| Per-op energy | 165.9 pJ | 206.8 pJ |
| EDP per pair | 331.8 × 40 = 13,272 aJ·s | 413.5 × 50 = 20,675 aJ·s |

**Theoretical dual-issue summary:**

| Metric | 2×MUL | Hybrid | Winner |
|---|---|---|---|
| Throughput (pairs/s) | 50.0M | 40.0M | 2×MUL (+25%) |
| Energy per pair | 331.8 pJ | 413.5 pJ | 2×MUL (−19.7%) |
| EDP per pair | 13,272 aJ·s | 20,675 aJ·s | 2×MUL (−35.8%) |
| Core power | 8.295 mW | 8.270 mW | Hybrid (−0.3%) |
| Core area | 62,641 µm² | 61,010 µm² | Hybrid (−2.6%) |
| **Multiplier power** | **3.037 mW** | **1.343 mW** | **Hybrid (−55.8%)** |
| **Area efficiency (pairs/s/µm²)** | **0.798** | **0.656** | 2×MUL (+21.8%) |

For throughput-critical dual-issue multiply workloads, 2×MUL is significantly faster. Hybrid's advantage is in power-constrained or area-constrained scenarios where the second multiply pipe is used infrequently.

### 8.8 Break-Even Analysis: When Does Hybrid Win?

Define multiply density `f_m` = fraction of cycles that issue a pipe-B multiply.

- Hybrid power advantage (multiplier): 3.037 − 1.343 = 1.694 mW
- Hybrid throughput loss per pipe-B op: +1 cycle (5 vs 4)
- Energy cost of 1 extra cycle: 82.7 pJ

At low `f_m`, idle power dominates and Hybrid saves 1.694 mW × duty fraction.
At high `f_m`, throughput loss dominates and 2×MUL wins.

Cross-over: Hybrid wins on total energy when:

$$f_m < \frac{P_{mul2} - P_{mule}}{e_{cyc} / T_{clk}} = \frac{1.017 - 0.155}{82.7 / 10} = \frac{0.862}{8.27} = 10.4\%$$

For workloads where less than ~10% of cycles involve a pipe-B multiply, Hybrid is more energy-efficient despite the extra latency.

---

## 9. Generalized Formulas

### Definitions

| Symbol | Meaning |
|---|---|
| $L_f$ | Fast path latency (cycles) |
| $L_e$ | Efficient path latency (cycles) |
| $\Delta L = L_e - L_f$ | Extra latency |
| $e_f = P_f \times L_f \times T_{clk}$ | Fast path energy per instruction |
| $e_e = P_e \times L_e \times T_{clk}$ | Efficient path energy per instruction |
| $D$ | Production-consumption distance (cycles of independent work before first consumer) |
| $s(D) = \max(0, \Delta L - D)$ | Exposed stall cycles |
| $e_{cyc} = P_{core} \times T_{clk}$ | Core energy per stall cycle |
| $N$ | Number of converted operations |

### 9.1 Energy Saving When Extra Latency Is Fully Absorbed

Full absorption condition: $D \geq \Delta L$ for each converted operation (i.e., $s(D) = 0$).

Total energy saving:

$$\Delta E_{full} = N \times (e_f - e_e)$$

Relative saving per converted op:

$$\eta_{full} = \frac{e_f - e_e}{e_f} = 1 - \frac{e_e}{e_f}$$

If only fraction $\rho$ of candidate operations can be converted with full absorption:

$$\Delta E_{full} = \rho \times N_{total} \times (e_f - e_e)$$

**Key insight:** When all extra latency is hidden by independent work, the energy benefit depends **only** on the per-op energy difference — latency cancels out.

### 9.2 General Energy-Latency Tradeoff vs Distance D

For a single operation with production-consumption distance $D$:

**Net energy saving:**

$$\Delta e_{net}(D) = (e_f - e_e) - s(D) \times e_{cyc}$$

**Break-even condition** (conversion is beneficial):

$$\Delta e_{net}(D) > 0 \iff (e_f - e_e) > s(D) \times e_{cyc}$$

Equivalent minimum distance:

$$D \geq \Delta L - \frac{e_f - e_e}{e_{cyc}}$$

**For a program with distance distribution $P(D = d)$:**

Expected exposed stall per converted op:

$$E[s] = \sum_d \max(0, \Delta L - d) \times P(D = d)$$

Expected net energy saving per converted op:

$$E[\Delta e_{net}] = (e_f - e_e) - e_{cyc} \times E[s]$$

For $N$ converted operations:

$$\Delta E = N \times E[\Delta e_{net}]$$
$$\Delta C = N \times E[s] \quad \text{(extra cycles)}$$
$$\Delta T = \Delta C \times T_{clk} \quad \text{(extra time)}$$

**EDP tradeoff** with baseline $(E_0, T_0)$:

$$E_1 = E_0 - \Delta E$$
$$T_1 = T_0 + \Delta T$$
$$\text{EDP ratio} = \frac{E_1 \times T_1}{E_0 \times T_0}$$

$\text{EDP ratio} < 1$ means the efficient path is better overall.

### 9.3 Instantiated Parameter Sets

| Parameter | Standalone (MUL→MULE) | Hybrid (pipe B: MUL2→MULE) |
|---|---|---|
| $L_f$ | 2 cycles | 3 cycles |
| $L_e$ | 5 cycles | 5 cycles |
| $\Delta L$ | 3 cycles | 2 cycles |
| $P_f$ | 1.188 mW (in-core) | 2.020 mW (2×MUL u_mul) |
| $P_e$ | 0.155 mW (in-core) | 0.155 mW (Hybrid u_mule) |
| $e_f$ | 23.76 pJ | 60.60 pJ |
| $e_e$ | 7.75 pJ | 7.75 pJ |
| $\Delta e = e_f - e_e$ | 16.01 pJ | 52.85 pJ |
| $e_{cyc}$ | 82.70 pJ | 82.70 pJ |
| Break-even D | $D \geq 3$ | $D \geq 2$ |
| $\eta_{full}$ | 67.4% | 87.2% |

**Critical observation:** Because $\Delta e < e_{cyc}$ in both cases, **even a single exposed stall cycle makes conversion a net energy loss.** The break-even is binary: either fully hidden or not worth converting.

---

## 10. Benchmark Trace Energy Analysis

Five kernel benchmarks were compiled for RISC-V, executed on the Spike ISA simulator, and their instruction traces analyzed for multiply-operation dependency distances using `mul_centric_analysis.py`.

The `energy_benchmark_analysis.py` script then computes per-kernel energy impact under three scenarios:
- **A) ALL:** convert every MUL → MULE (aggressive)
- **B) FULLY HIDDEN only:** convert only ops with $D \geq \Delta L$ (zero stall)
- **C) PARTIALLY HIDDEN only:** convert ops with $0 < D < \Delta L$ (some stall)

### 10.1 Kernel Characteristics

| Kernel | Source | Dynamic Insns | MUL ops | MUL% | D distribution |
|---|---|---|---:|---:|---|
| dotprod | `dotprod.c` | 9,219 | 1,024 | 11.1% | D=1: 1024 |
| FIR filter | `fir.c` | 112,896 | 16,128 | 14.3% | D=1: 16128 |
| Horner eval | `horner.c` | 12,288 | 2,048 | 16.7% | D=1: 2048 |
| Matrix mul | `matmul.c` | 268,384 | 32,768 | 12.2% | D=2: 32768 |
| Unrolled dot | `unrolled_dot.c` | 19,456 | 4,096 | 21.1% | D=2:1024, D=3:2048, D=4:1024 |

All MUL consumers are `add` instructions (multiply-accumulate patterns). The distance $D$ is the number of instructions between the MUL producing a result and the first consumer reading it (IPC ≈ 1 assumption maps instructions to cycles).

### 10.2 Results: Hybrid Config (ΔL=2, e_mul=60.60 pJ, e_mule=7.75 pJ)

| Kernel | FH% (D≥2) | PH% | Net ALL (pJ) | ALL %core | Net FH-only (pJ) | FH %core | PH/op (pJ) |
|---|---:|---:|---:|---:|---:|---:|---:|
| dotprod | 0% | 100% | −30,566 | −4.0% | 0 | 0% | −29.85 |
| FIR | 0% | 100% | −481,421 | −5.2% | 0 | 0% | −29.85 |
| Horner | 0% | 100% | −61,133 | −6.0% | 0 | 0% | −29.85 |
| **matmul** | **100%** | 0% | **+1,731,789** | **+7.8%** | **+1,731,789** | **+7.8%** | n/a |
| **unrolled_dot** | **100%** | 0% | **+216,474** | **+13.5%** | **+216,474** | **+13.5%** | n/a |

*Source: `energy_analysis_hybrid.txt`*

### 10.3 Results: Standalone Config (ΔL=3, e_mul=23.76 pJ, e_mule=7.75 pJ)

| Kernel | FH% (D≥3) | PH% | Net ALL (pJ) | ALL %core | Net FH-only (pJ) | FH %core | PH/op (pJ) |
|---|---:|---:|---:|---:|---:|---:|---:|
| dotprod | 0% | 100% | −152,975 | −20.1% | 0 | 0% | −149.39 |
| FIR | 0% | 100% | −2,409,362 | −25.8% | 0 | 0% | −149.39 |
| Horner | 0% | 100% | −305,951 | −30.1% | 0 | 0% | −149.39 |
| matmul | 0% | 100% | −2,185,298 | −9.8% | 0 | 0% | −66.69 |
| **unrolled_dot** | **75%** | 25% | −19,108 | −1.2% | **+49,183** | **+3.1%** | −66.69 |

*Source: `energy_analysis_standalone.txt`*

### 10.4 Side-by-Side Comparison: ΔL=2 vs ΔL=3

| Kernel | ΔL=2 FH% | ΔL=2 Net FH | ΔL=3 FH% | ΔL=3 Net FH | Impact of +1 ΔL |
|---|---:|---:|---:|---:|---|
| dotprod | 0% | 0 | 0% | 0 | No change (D=1 in both) |
| FIR | 0% | 0 | 0% | 0 | No change (D=1 in both) |
| Horner | 0% | 0 | 0% | 0 | No change (D=1 in both) |
| matmul | 100% | **+1.73 nJ (+7.8%)** | 0% | 0 | **Loses entire benefit** (D=2 < ΔL=3) |
| unrolled_dot | 100% | **+216 nJ (+13.5%)** | 75% | +49.2 nJ (+3.1%) | **−77% benefit** (D=2 ops now exposed) |

### 10.5 Key Findings

1. **Binary threshold behavior:** Kernels split cleanly into fully-hideable (D ≥ ΔL) and not-worth-converting (D < ΔL). There is no partial benefit — any exposed stall exceeds the energy saving.

2. **ΔL sensitivity is extreme:** Adding just one cycle to ΔL (2→3) eliminates matmul's entire 7.8% saving and reduces unrolled_dot's by 77%. Each cycle of extra latency requires one more instruction of independent work in the consumer chain.

3. **Loop unrolling is the key enabler:** `unrolled_dot` achieves D=3–4 through 4× loop unrolling, making 75% of its ops fully hideable even at ΔL=3. The same kernel without unrolling (`dotprod`) has D=1 and gains nothing.

4. **Accumulate chains are the worst case:** dot, FIR, and Horner all follow the pattern `acc += a[i] * b[i]` where the multiply result feeds directly into the next accumulate — D=1 by construction.

5. **Selective conversion is essential:** Even in `unrolled_dot` (ΔL=3), converting ALL ops loses energy (−1.2%), but converting only the D≥3 subset saves +3.1%. A compiler/scheduler must distinguish between fully-hidden and partially-hidden sites.

---

## Appendix A: Leakage Scaling at Advanced Nodes

At 45 nm, leakage is 6.9–14.8% of multiplier power. At advanced nodes, leakage dominates.

MULE area reduction: $\alpha_{mul} = 52.7\%$ (of multiplier block).
Core-level area reduction: $\alpha_{core} = \frac{4516}{61010} \times 52.7\% \approx 3.9\%$.

| Leakage fraction $\lambda$ | Technology | $\Delta P/P \approx \lambda \times \alpha_{core}$ |
|---|---|---|
| 15% | 45 nm (measured) | ~0.6% |
| 30% | 16/14 nm | ~1.2% |
| 50% | 7/5 nm | ~2.0% |

At advanced nodes, MULE's area advantage translates to increasingly significant total-power reduction.

---

## Appendix B: Notation Reference

| Symbol | Definition | Unit |
|---|---|---|
| EPI | Energy Per Instruction ($P \times L \times T_{clk}$) | pJ |
| EDP | Energy-Delay Product ($EPI \times T_{latency}$) | aJ·s |
| $P_{dynamic}$ | Internal + Switching power (no leakage) | mW |
| $D$ | Production-consumption distance | cycles |
| FH | Fully Hidden ($D \geq \Delta L$) | — |
| PH | Partially Hidden ($0 < D < \Delta L$) | — |

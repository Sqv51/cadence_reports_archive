# MUL vs MULE — Energy Per Instruction (EPI) Analysis

**Technology:** NanGate45 (45 nm, 1.1V)  
**Clock:** 100 MHz (10 ns period)  
**Tool Flow:** Genus DDI 25.1 → Innovus DDI 25.1 (post-route, VCD-based power)  
**Date:** 2026-03-24

---

## 1. Architecture & Latency

| | MUL (Booth-Wallace) | MULE (Iterative Partial Products) |
|---|---|---|
| **Architecture** | Full 33×33 combinational multiply tree | 16×16 multiplier reused 3× via FSM |
| **Pipeline** | 2-stage fixed-latency (E1 → E2) | 5-state FSM (IDLE → CALC0 → CALC1 → CALC2 → DONE) |
| **Cycles per instruction** | **2** | **5** |
| **Latency @100 MHz** | 20 ns | 50 ns |
| **Critical path (Genus)** | 4.606 ns (53% slack) | 2.996 ns (69% slack) |

### MUL Pipeline Detail
- **E1:** Latch operands + combinational 33×33 Booth-Wallace tree multiplication
- **E2:** Register the result → output on `writeback_value_o`

### MULE FSM Detail
- **IDLE:** Latch operands A, B when `opcode_valid_i` asserts
- **CALC0:** Compute P0 = A_low × B_low (16×16)
- **CALC1:** Compute P1 = A_low × B_high (16×16)
- **CALC2:** Compute P2 = A_high × B_low (16×16)
- **DONE:** Combine: result = P0 + (P1 << 16) + (P2 << 16), assert `writeback_valid_o`

---

## 2. Power Data (Innovus Post-Route, VCD-Based)

### 2.1 Standalone Module Power

| Metric | MUL | MULE | Difference |
|---|---|---|---|
| Internal Power | 0.6515 mW | 0.1383 mW | −78.8% |
| Switching Power | 0.5601 mW | 0.0878 mW | −84.3% |
| Leakage Power | 0.0895 mW | 0.0392 mW | −56.2% |
| **Total Power** | **1.301 mW** | **0.265 mW** | **−79.6%** |
| Instances | 2341 | 834 | −64.4% |
| Cell Area | 4536 µm² | 2152 µm² | −52.6% |

### 2.2 In-Core Instance Power (within `riscv_core`)

Both measured from the **same VCD simulation** (`core_tb_mul_compare.vcd`), same core netlist.

| Metric | u_mul | u_mule | Difference |
|---|---|---|---|
| Internal Power | 0.5954 mW | 0.0871 mW | −85.4% |
| Switching Power | 0.4663 mW | 0.0280 mW | −94.0% |
| Leakage Power | 0.1263 mW | 0.0399 mW | −68.4% |
| **Total Power** | **1.188 mW** | **0.1549 mW** | **−87.0%** |
| % of Core (8.270 mW) | 14.36% | 1.87% | — |

---

## 3. Energy Per Instruction (EPI)

$$EPI = P_{avg} \times N_{cycles} \times T_{clk}$$

Where:
- P_avg = average power during multiply execution
- N_cycles = cycles per multiply instruction (MUL: 2, MULE: 5)
- T_clk = 10 ns (100 MHz)

### 3.1 Standalone EPI (module-level VCD)

| | MUL | MULE | Reduction |
|---|---|---|---|
| Power (P_avg) | 1.301 mW | 0.265 mW | −79.6% |
| Cycles (N) | 2 | 5 | +150% |
| **EPI** | **26.02 pJ** | **13.25 pJ** | **−49.1%** |

### 3.2 In-Core EPI (instance-level VCD)

| | u_mul | u_mule | Reduction |
|---|---|---|---|
| Power (P_avg) | 1.188 mW | 0.1549 mW | −87.0% |
| Cycles (N) | 2 | 5 | +150% |
| **EPI** | **23.76 pJ** | **7.75 pJ** | **−67.4%** |

---

## 4. Energy-Delay Product (EDP)

$$EDP = EPI \times T_{latency}$$

Where T_latency = N_cycles × T_clk.

| | MUL | MULE | Difference |
|---|---|---|---|
| Standalone EDP | 520.4 aJ·s | 662.5 aJ·s | MULE 27% worse |
| **In-Core EDP** | **475.2 aJ·s** | **387.3 aJ·s** | **MULE 18.5% better** |

---

## 5. Area Efficiency

| Metric | MUL | MULE | Difference |
|---|---|---|---|
| Cell Area | 4536 µm² | 2152 µm² | −52.6% |
| Wire Length | 32.6 mm | 9.76 mm | −70.1% |
| Core Die Area | 6459 µm² | 3060 µm² | −52.6% |
| Utilization | 70.2% | 70.3% | Same |
| EPI / Area | 5.74 fJ/µm² | 6.16 fJ/µm² | Comparable |
| In-Core EPI / Area | 5.24 fJ/µm² | 3.60 fJ/µm² | **MULE 31% better** |

---

## 6. Key Findings

1. **MULE uses 49–67% less energy per multiply instruction** despite taking 2.5× more cycles. The massive power reduction (80–87%) more than compensates for the latency penalty.

2. **In-core EDP favors MULE by 18.5%.** Real workload VCD shows MULE's effective power gating when idle — switching power drops 94% compared to MUL.

3. **Standalone EDP slightly favors MUL** (+27%) because the standalone testbench exercises the multiplier back-to-back with less idle benefit for MULE.

4. **Leakage advantage compounds over time.** MULE leaks 0.039 mW vs MUL's 0.090 mW (−56%). For workloads where multiplications are infrequent (typical RISC-V code), MULE's idle power advantage grows further.

5. **MULE achieves 53% area reduction** with identical utilization density (70%). The 16×16 reused multiplier eliminates 67% of full adders (121 vs 370 FA_X1 instances) and 70% of wiring.

6. **MULE has better timing margin** (6.9 ns slack vs 5.3 ns), enabling potential voltage scaling for further energy savings.

---

## 7. Summary

| Metric | MUL | MULE | Winner |
|---|---|---|---|
| Latency (cycles) | 2 | 5 | MUL |
| Power (standalone) | 1.301 mW | 0.265 mW | **MULE** |
| Power (in-core) | 1.188 mW | 0.155 mW | **MULE** |
| EPI (standalone) | 26.02 pJ | 13.25 pJ | **MULE** |
| EPI (in-core) | 23.76 pJ | 7.75 pJ | **MULE** |
| EDP (standalone) | 520.4 aJ·s | 662.5 aJ·s | MUL |
| EDP (in-core) | 475.2 aJ·s | 387.3 aJ·s | **MULE** |
| Area | 4536 µm² | 2152 µm² | **MULE** |
| Timing Slack | 5.3 ns | 6.9 ns | **MULE** |

---

## 8. Generalized Formulas

Definitions (applied to MUL vs MULE single-unit comparison):

- Fast path (MUL): latency `L_f = 2` cycles, energy/op `e_f = 23.76 pJ` (in-core)
- Efficient path (MULE): latency `L_e = 5` cycles, energy/op `e_e = 7.75 pJ` (in-core)
- Extra latency: `ΔL = L_e - L_f = 3` cycles
- Production-consumption distance: `D` (cycles of independent work before first consume)
- Exposed stall: `s(D) = max(0, ΔL - D)`
- Core energy/cycle: `e_cyc = 8.270 mW × 10 ns = 82.7 pJ`

### 8.1) Energy Saving When Extra Latency Is Fully Absorbed

Full absorption condition: `D >= 3` for each converted operation.

Total energy saving from converting `N` operations:

`ΔE_full = N × (e_f - e_e) = N × 16.01 pJ`

Relative saving per converted op:

`η_full = (e_f - e_e) / e_f = 1 - 7.75/23.76 = 67.4%`

### 8.2) General Energy-Latency Tradeoff vs Production-Consumption Distance

For a single operation with distance `D`:

- Net energy saving: `Δe_net(D) = 16.01 - max(0, 3 - D) × 82.7 pJ`
- Break-even: `Δe_net(D) > 0 ⟺ max(0, 3-D) < 0.194 ⟺ D >= 3`

Since `e_f - e_e = 16.01 pJ < e_cyc = 82.7 pJ`, even one exposed stall cycle makes conversion a net loss. Only fully hidden ops (D ≥ 3) benefit.

For a program with distance distribution P(D=d):

- Expected stall: `E[s] = Σ_d max(0, 3-d) × P(D=d)`
- Net saving/op: `E[Δe_net] = 16.01 - 82.7 × E[s]`
- EDP ratio: `(E0 - N×E[Δe_net]) × (T0 + N×E[s]×Tclk) / (E0 × T0)`

---

## 9. Leakage Difference at Lower Technology Nodes

At 45 nm, leakage fraction is moderate. At advanced nodes (7/5/3 nm), leakage dominates.

First-order model using MULE area reduction `α = 52.6%` (of multiplier block):

- Multiplier-fraction of core area: `4536/61009 ≈ 7.4%`
- Core-level area reduction from MULE: `α_core ≈ 7.4% × 52.6% ≈ 3.9%`

Projected total-power reduction from leakage scaling:

| Leakage fraction `λ` | Technology regime | `ΔP/P ≈ λ × α_core` |
|---|---|---|
| 15% | 45 nm (measured) | ~0.6% |
| 30% | 16/14 nm | ~1.2% |
| 50% | 7/5 nm | ~2.0% |

MULE's 52.6% area reduction becomes significantly more valuable at advanced nodes where leakage power dominates.

---

## 10. Trace-Based Energy Analysis on Real Kernel Benchmarks

Energy parameters for standalone MUL→MULE replacement:

| Parameter | Value | Source |
|---|---|---|
| `P_mul` | 1.188 mW | power_inst_a.rpt (Hybrid cfg, in-core MUL) |
| `P_mule` | 0.155 mW | power_inst_b.rpt (Hybrid cfg, in-core MULE) |
| `L_mul` | 2 cycles | RTL / xrun |
| `L_mule` | 5 cycles | RTL / xrun |
| `ΔL` | 3 cycles | 5 − 2 |
| `e_mul` | 23.76 pJ | 1.188 mW × 2 × 10 ns |
| `e_mule` | 7.75 pJ | 0.155 mW × 5 × 10 ns |
| `Δe` | 16.01 pJ/op | saving at zero stall |
| `e_cyc` | 82.70 pJ | 8.270 mW × 10 ns |

Break-even: `D ≥ 3` (any exposed stall destroys the 16.01 pJ saving since `e_cyc = 82.7 pJ >> Δe`)

### 10.1) Per-Kernel Results (Spike ISA traces, IPC≈1 assumption)

| Kernel | Insns | MUL ops | MUL% | D distribution | FH% (D≥3) | PH% (D<3) |
|---|---:|---:|---:|---|---:|---:|
| dotprod | 9,219 | 1,024 | 11.1% | D=1: 1024 | 0% | 100% |
| FIR filter | 112,896 | 16,128 | 14.3% | D=1: 16128 | 0% | 100% |
| Horner eval | 12,288 | 2,048 | 16.7% | D=1: 2048 | 0% | 100% |
| Matrix mul | 268,384 | 32,768 | 12.2% | D=2: 32768 | 0% | 100% |
| Unrolled dot | 19,456 | 4,096 | 21.1% | D=2:1024, D=3:2048, D=4:1024 | 75% | 25% |

### 10.2) Cross-Benchmark Energy Summary (ΔL=3)

| Kernel | Net ALL (pJ) | ALL %core | Net FH-only (pJ) | FH %core | PH per-op |
|---|---:|---:|---:|---:|---:|
| dotprod | −152,975 | −20.1% | 0 | 0% | −149.39 pJ |
| FIR | −2,409,362 | −25.8% | 0 | 0% | −149.39 pJ |
| Horner | −305,951 | −30.1% | 0 | 0% | −149.39 pJ |
| matmul | −2,185,298 | −9.8% | 0 | 0% | −66.69 pJ |
| unrolled_dot | −19,108 | −1.2% | **+49,183** | **+3.1%** | −66.69 pJ |

### 10.3) Key Findings (ΔL=3 standalone)

1. **Only `unrolled_dot` has any fully-hideable ops** — 75% of its MUL ops have D≥3, yielding +3.1% core energy saving when converting only those.

2. **matmul drops from +7.8% saving (ΔL=2) to −9.8% loss (ΔL=3)** — all its ops have D=2, which was fully hidden at ΔL=2 but now exposes 1 stall cycle each.

3. **D=1 kernels (dot, FIR, Horner) are 5× worse** — each op exposes 2 stall cycles (vs 1 at ΔL=2), costing 149.39 pJ/op net loss.

4. **Selective conversion is critical** — converting only D≥3 ops in `unrolled_dot` saves +49.2 nJ; converting all ops loses −19.1 nJ.

### 10.4) Comparison: ΔL=3 (standalone) vs ΔL=2 (hybrid dual-core)

| Kernel | ΔL=2: FH% | ΔL=2: Net FH | ΔL=3: FH% | ΔL=3: Net FH |
|---|---:|---:|---:|---:|
| dotprod | 0% | 0 | 0% | 0 |
| FIR | 0% | 0 | 0% | 0 |
| Horner | 0% | 0 | 0% | 0 |
| matmul | 100% | **+1.73 nJ (+7.8%)** | 0% | 0 |
| unrolled_dot | 100% | **+216 nJ (+13.5%)** | 75% | **+49.2 nJ (+3.1%)** |

The extra cycle of latency (ΔL=3 vs ΔL=2) eliminates matmul's benefit entirely and reduces unrolled_dot's benefit by 77%. This demonstrates the steep sensitivity to ΔL — each additional cycle of latency penalty dramatically narrows the set of beneficial conversions.

Note: Unlike the dual-unit hybrid comparison (ΔL=2, e_mul=60.60pJ), the standalone replacement uses in-core instance power (e_mul=23.76pJ). The per-op saving is smaller (16.01 vs 52.85 pJ), making the break-even condition stricter.

---

## 11. Parallelized Deployment Comparison

### A) Fixed core count (`K` cores)

Using in-core EPI and latency:

| Metric | MUL-core | MULE-core | Ratio |
|---|---|---|---|
| Multiply EPI | 23.76 pJ | 7.75 pJ | MULE 67.4% better |
| Multiply latency | 20 ns | 50 ns | MUL 2.5× faster |
| In-core EDP | 475.2 aJ·s | 387.3 aJ·s | MULE 18.5% better |

At equal core count, relative ratios are preserved: MULE wins EPI and in-core EDP; MUL wins latency.

### B) Fixed silicon area budget

MULE-core is 3.9% smaller (core-level area reduction from multiplier swap).

Feasible core count gain: `K_mule/K_mul ≈ 1/0.961 = 1.041`

| Metric | MUL (K cores) | MULE (1.041K cores) | Ratio |
|---|---|---|---|
| Aggregate throughput | K × T_mul | 1.041K × T_mule | MUL faster per-core, MULE offset by +4.1% cores |
| Aggregate EDP | K × 475.2 aJ·s | 1.041K × 387.3 aJ·s | **MULE 15.2% better** |
| Per-core EPI | 23.76 pJ | 7.75 pJ | **MULE 67.4% better** |

Under fixed area, MULE wins on EDP and EPI; MUL retains per-operation latency advantage (2.5×).

---

## Next Analysis TODO

1. Completed: generalized formula for energy saving while fully absorbing latency.
2. Completed: generalized formula for energy-latency tradeoff vs production-consumption distance.
4. Completed (trace-based): energy savings from fully-hidden-only conversion on 5 kernel benchmarks.
5. Completed (trace-based): energy savings calculation on real kernel traces (dot, FIR, Horner, matmul, unrolled_dot).
6. Completed: leakage-difference acknowledgement and scaling model for lower-nm technologies.
7. Completed: parallelized deployment comparison (fixed-core and fixed-area) for EDP, EPI, and latency.

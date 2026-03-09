# Progress Report
## Energy-Efficient Alternative Functional Unit Switching on RISC-V

**Student:** Şükrü Yiğit Karaağaç  
**Supervisor:** Dr. İsmail Aktürk, Department of Computer Science  
**Date:** March 9, 2026  
**Report Type:** Progress Update

---

## 1. Executive Summary

This report presents the current status of energy-per-instruction (EPI) analysis comparing five multiplier architectures integrated into the biRISC-V processor core. Two technology nodes have been evaluated:

- **ASAP7 (7nm):** Synthesis-level (Genus) power analysis with VCD-based switching activity
- **NanGate45 (45nm):** Full synthesis + place-and-route (Genus + Innovus) power analysis with VCD-based switching activity

Key finding: **The energy ranking of multiplier units changes between technology nodes and between pre-layout and post-layout analysis**, driven primarily by the relative contribution of leakage power and wire parasitic capacitance.

---

## 2. Methodology

### 2.1 Design Under Test

The design is `riscv_core` from the biRISC-V open-source dual-issue RISC-V processor, modified to instantiate five multiplier variants simultaneously within the execution unit:

| Instance | Architecture | Description |
|----------|-------------|-------------|
| `u_mul`  | Booth-Wallace tree | Standard single-cycle RISC-V M-extension multiplier |
| `u_mule` | Iterative FSM | Energy-efficient multi-cycle multiplier |
| `u_muls` | Shift-and-add | Simplified iterative multiplier |
| `u_cbm`  | Column bypass | Reduced switching via column-wise bypassing |
| `u_mulp` | Deep pipeline | Multi-stage pipelined multiplier |

All five multipliers receive the same inputs and execute in parallel during each multiply instruction, ensuring identical workload and fair power comparison.

#### Multiplier Latencies

| Instance | RTL Latency (cycles) | Latency (ns) @ 100 MHz | Determination |
|----------|:--------------------:|:----------------------:|---------------|
| `u_mul`  | 2 | 20 | `MULT_STAGES = 2` localparam; operands registered in cycle 1, combinational `*` + result registered in cycle 2 |
| `u_mule` | 5 | 50 | FSM: IDLE → CALC0 → CALC1 → CALC2 → DONE; confirmed by simulation log (avg 5.000 cycles over 1,000 ops) |
| `u_muls` | 2 | 20 | 2-stage pipeline identical to `u_mul`: operand register → combinational `*` → result register |
| `u_cbm`  | ~9.5 avg (2–34) | ~95 avg | Data-dependent: popcount(sparser operand) + 2 cycles; FSM iterates over set bits via `lowest_index()`. Confirmed by simulation (avg 9.500 cycles). Zero operand fast-path: 2 cycles |
| `u_mulp` | 6 | 60 | `MULT_STAGES = 6` parameter; 1 input stage + 5 shift-register pipeline stages. Recommended range 4–8 |

**Note:** These are raw multiplier latencies. The biRISC-V issue pipeline adds ~1 cycle of overhead visible in end-to-end simulation measurements (e.g., `u_mul` measured as 3 cycles in simulation).

### 2.2 VCD Generation

**Tool:** Synopsys VCS X-2025.06-SP2 (RTL simulation)

A custom RISC-V assembly program (`test_mul_compare5.s`) exercises all five multipliers with 1,000 multiply operations using pseudo-random operand pairs (16-bit × 17-bit, PRNG-generated, non-zero). The program:

1. Generates two pseudo-random operands per iteration via additive PRNG
2. Dispatches all five multiply instructions (one standard `MUL`, four custom-opcode variants)
3. Waits for all results, verifies correctness (all five results must match)
4. Repeats for 1,000 iterations

**VCD characteristics:**
- File size: 269 MB
- Total simulation cycles: 76,900
- Scope: `tb_mul5/u_dut` (full `riscv_core` hierarchy)

### 2.3 Synthesis (Genus DDI 25.1)

Power-optimized synthesis settings:
- `design_power_effort high`
- `syn_generic_effort low`, `syn_map_effort low`, `syn_opt_effort low`
- Clock: 100 MHz (10 ns period) — intentionally relaxed to minimize timing pressure and allow the optimizer to focus on power
- No clock gating (disabled due to CTS complications in Innovus; discussed in Section 5)

VCD-based power analysis in Genus:
```tcl
read_vcd $vcd_file -vcd_scope tb_mul5/u_dut
report_power -inst $multiplier_instance
```

### 2.4 Place & Route (Innovus DDI 25.1) — NanGate45 Only

- Power-driven placement: `place_global_activity_power_driven true`, `place_global_clock_power_driven true`
- `setOptMode -powerEffort high`
- Clock tree synthesis via `clock_opt_design`
- Post-route optimization: `optDesign -postRoute`
- Post-route VCD-based power: `read_activity_file -format VCD` → `report_power -instances`

**Note:** ASAP7 Innovus P&R was not possible because the Cadence license server does not include the `invs_7nm` feature token required for sub-10nm place-and-route. The base `invs` license supports nodes ≥ 28nm only. Genus synthesis does not have this node restriction, which is why ASAP7 synthesis completed successfully.

### 2.5 Energy-per-Instruction Calculation

$$EPI = \frac{P_{avg} \times T_{total}}{N_{instructions}}$$

Where:
- $P_{avg}$ = VCD-annotated **average** power of the multiplier instance over the full simulation (W)
- $T_{total}$ = 76,900 cycles × 10 ns = 769 µs
- $N_{instructions}$ = 1,000 multiply operations

**Important:** Multiplier latency is **not** a factor in EPI. The VCD-based $P_{avg}$ is the time-average over the entire simulation window, which already captures the duty cycle of each multiplier — a multiplier that is active for 5 cycles per operation naturally toggles more per operation than one active for 2 cycles, and its $P_{avg}$ is correspondingly higher. Multiplying by latency again would double-count the effect. If one were using *active-only* power (measured only during the cycles when the unit is computing), then energy would equal $P_{active} \times L \times T_{clk}$, but that is not what the Genus/Innovus VCD power reports provide.

### 2.6 Energy-Delay Product (EDP)

To capture the trade-off between energy efficiency and performance, the EDP is computed as:

$$EDP = EPI \times L_{cycles} \times T_{clk}$$

Where:
- $L_{cycles}$ = multiplier latency in clock cycles (from RTL design)
- $T_{clk}$ = 10 ns (100 MHz clock period)

Lower EDP indicates a better energy–performance trade-off. An architecture that is very energy-efficient but extremely slow (high latency) will be penalized, and vice versa.

---

## 3. Results

### 3.1 ASAP7 (7nm) — Genus Synthesis Only

| Rank | Multiplier | Total Power (µW) | Leakage % | Internal % | Switching % | Latency (cyc) | EPI (pJ) | EDP (pJ·ns) |
|------|-----------|-------------------|-----------|------------|-------------|:-------------:|:--------:|:-----------:|
| 1 | u_mul | 26.89 | 0.8% | 95.8% | 3.3% | 2 | 20.68 | 413.6 |
| 2 | u_muls | 28.68 | 0.4% | 97.7% | 1.9% | 2 | 22.06 | 441.2 |
| 3 | u_mule | 38.33 | 0.3% | 92.9% | 6.8% | 5 | 29.48 | 1,474.0 |
| 4 | u_cbm | 50.66 | 0.2% | 77.6% | 22.2% | ~9.5 | 38.96 | 3,701.2 |
| 5 | u_mulp | 60.22 | 0.2% | 98.9% | 0.9% | 6 | 46.31 | 2,778.6 |

**EDP ranking:** u_mul (413.6) < u_muls (441.2) < u_mule (1,474.0) < u_mulp (2,778.6) < u_cbm (3,701.2)

**VCD annotation coverage in Genus (ASAP7):** 21.19% of RTL driver nets annotated; 11.57% of all driver nets annotated. Flop annotation: 58.78%.

### 3.2 NanGate45 (45nm) — Genus Synthesis Only

| Rank | Multiplier | Total Power (µW) | Leakage % | Internal % | Switching % | Latency (cyc) | EPI (pJ) | EDP (pJ·ns) |
|------|-----------|-------------------|-----------|------------|-------------|:-------------:|:--------:|:-----------:|
| 1 | u_muls | 287.2 | 26.5% | 71.6% | 1.9% | 2 | 220.9 | 4,418 |
| 2 | u_mule | 316.7 | 19.2% | 75.7% | 5.1% | 5 | 243.6 | 12,180 |
| 3 | u_mul | 358.7 | 43.9% | 53.4% | 2.8% | 2 | 275.9 | 5,518 |
| 4 | u_cbm | 387.4 | 15.4% | 65.8% | 18.8% | ~9.5 | 297.9 | 28,301 |
| 5 | u_mulp | 526.3 | 16.4% | 82.6% | 1.0% | 6 | 404.7 | 24,282 |

**EDP ranking:** u_muls (4,418) < u_mul (5,518) < u_mule (12,180) < u_mulp (24,282) < u_cbm (28,301)

**VCD annotation coverage in Genus (NanGate45):** 21.35% of RTL driver nets annotated; 12.52% of all driver nets annotated. Flop annotation: 73.96%.

### 3.3 NanGate45 (45nm) — Post-Route (Innovus)

| Rank | Multiplier | Total Power (mW) | Leakage % | Internal % | Switching % | Area (µm²) | Cells | Latency (cyc) | EPI (pJ) | EDP (pJ·ns) |
|------|-----------|-------------------|-----------|------------|-------------|------------|-------|:-------------:|:--------:|:-----------:|
| 1 | u_muls | 0.169 | 32.0% | 47.6% | 20.4% | 2,572 | 1,187 | 2 | 129.8 | 2,596 |
| 2 | u_mule | 0.239 | 18.9% | 54.3% | 26.8% | 2,325 | 990 | 5 | 183.7 | 9,185 |
| 3 | u_mulp | 0.265 | 24.2% | 57.7% | 18.1% | 3,218 | 1,306 | 6 | 203.4 | 12,204 |
| 4 | u_cbm | 0.326 | 14.6% | 52.2% | 33.2% | 2,444 | 1,457 | ~9.5 | 250.8 | 23,826 |
| 5 | u_mul | 1.522 | 17.1% | 50.3% | 32.6% | 4,805 | 2,316 | 2 | 1,170.4 | 23,408 |

**EDP ranking:** u_muls (2,596) < u_mule (9,185) < u_mulp (12,204) < u_mul (23,408) < u_cbm (23,826)

**VCD annotation coverage in Innovus:** 9.79% of nets annotated (4,149 out of 42,384 nets). 3.83% of annotated nets had zero toggles.

### 3.4 Stage-by-Stage Power Trend (NanGate45 Innovus)

| Stage | Total Design Power (mW) |
|-------|------------------------|
| Post-Synthesis | 13.19 |
| Floorplan | 13.19 |
| Pre-CTS | 12.23 |
| Post-CTS | 9.41 |
| Post-Route | 9.49 |
| Post-Route Opt | 9.48 |

---

## 4. Key Observations

### 4.1 Ranking Reversal Between Technologies

The most significant finding is that `u_mul` (Booth-Wallace) ranks **#1 at 7nm** but drops to **#5 (last) at 45nm post-route**. The primary driver is leakage power:

- At **7nm**, leakage is <1% of total power — `u_mul`'s 2× larger area (4,805 µm² vs. ~2,300 µm² for others) incurs negligible leakage cost, and its single-cycle execution minimizes dynamic power per operation.
- At **45nm**, leakage accounts for 17–44% of total power. The 45nm library exhibits approximately 600–700× higher leakage per cell compared to the 7nm library. `u_mul`'s larger cell count directly translates to proportionally higher leakage.

### 4.2 Energy-Delay Product (EDP) Analysis

EDP captures the joint optimization of energy and latency. A key observation is that **EDP is more stable across technologies and flow stages than EPI alone**, because it penalizes high-latency architectures even when they are energy-efficient.

| Multiplier | ASAP7 Genus EDP (pJ·ns) | Rank | NG45 Genus EDP (pJ·ns) | Rank | NG45 Post-Route EDP (pJ·ns) | Rank |
|-----------|:-----------------------:|:----:|:----------------------:|:----:|:---------------------------:|:----:|
| u_mul | 413.6 | 1 | 5,518 | 2 | 23,408 | 4 |
| u_mule | 1,474.0 | 3 | 12,180 | 3 | 9,185 | 2 |
| u_muls | 441.2 | 2 | 4,418 | 1 | 2,596 | 1 |
| u_cbm | 3,701.2 | 5 | 28,301 | 5 | 23,826 | 5 |
| u_mulp | 2,778.6 | 4 | 24,282 | 4 | 12,204 | 3 |

**Key insights:**
- **`u_muls` is consistently #1 or #2 in EDP** across all experiments. Its 2-cycle latency combined with moderate energy makes it the best overall energy–performance trade-off.
- **`u_mul` drops from EDP #1 at 7nm to #4 at 45nm post-route.** While its 2-cycle latency is optimal, the 49× switching power amplification after P&R at 45nm overwhelms the latency benefit.
- **`u_cbm` is consistently last in EDP** due to its ~9.5-cycle average latency. Even though its per-instruction energy is competitive, the high latency destroys the EDP trade-off.
- **`u_mule` benefits from moderate latency (5 cycles)** and relatively low energy, placing it mid-range consistently.
- **`u_mulp`'s 6-cycle latency** and deep pipeline provide moderate EDP despite higher absolute energy.

### 4.3 Post-Route Switching Power Amplification

Place-and-route introduces real wire parasitics that are absent in synthesis. The observed switching power amplification from Genus to Innovus at 45nm:

| Multiplier | Genus Switching % | Innovus Switching % | Switching Power Amplification |
|-----------|-------------------|---------------------|-------------------------------|
| u_mul | 2.8% | 32.6% | 49.2× |
| u_muls | 1.9% | 20.4% | 6.4× |
| u_mule | 5.1% | 26.8% | 4.0× |
| u_cbm | 18.8% | 33.2% | 1.5× |
| u_mulp | 1.0% | 18.1% | 9.1× |

`u_mul` suffers the most (49.2×) because its Booth-Wallace tree has 2,316 cells with deep combinational paths creating long interconnect wires. This effect would be present (and potentially amplified) at 7nm as well, where interconnect resistance is higher due to thinner metal layers.

---

## 5. Limitations and Caveats

### 5.1 VCD Annotation Coverage (CRITICAL)

The VCD annotation coverage is a significant limitation:

- **Genus RTL annotation:** Only **21% of RTL driver nets** are annotated from the VCD. The remaining 79% of nets use Genus's default toggle rate assumption (typically 0.1–0.2 static probability with propagation). This means approximately 4/5 of the design's switching activity is estimated, not measured.
- **Innovus gate-level annotation:** Only **9.8% of post-route nets** (4,149/42,384) are annotated. This is expected because the VCD was generated from RTL simulation, not gate-level simulation. After synthesis, technology mapping creates many new internal nets (buffer chains, decomposed logic, clock tree buffers) that have no counterpart in the RTL VCD.

**Impact:** The VCD provides accurate toggle rates for the primary ports, register outputs, and RTL-visible signals. For the multiplier instances specifically, the input operands and output results are correctly annotated, which means the **relative comparison between multipliers is more reliable than the absolute power numbers**. However, unannotated internal nets rely on activity propagation algorithms whose accuracy is tool-dependent.

**Mitigation:** Gate-level simulation with SDF back-annotation would provide near-100% annotation coverage, but is significantly more computationally expensive and was not performed in this study.

### 5.2 VCD Testbench Appropriateness

**Strengths:**
- All five multipliers execute identically in parallel — ensuring a fair, controlled comparison
- 1,000 iterations with PRNG-generated operands provide statistical significance for average power
- Correctness verification (all results must match) ensures hardware is functioning properly
- Full `riscv_core` is exercised (not just isolated multiplier), capturing realistic interactions with the pipeline, issue unit, and register file

**Weaknesses:**
- Operands are **16-bit × 17-bit** (masked from 32-bit PRNG), not full 32-bit × 32-bit. This means the upper bits of the multiplier input are always zero, which may underrepresent switching activity for architectures that process all 32 bits (like Booth-Wallace). This could **artificially favor** `u_mul` in our results.
- The workload is **pure multiply** — in real applications, multiplies are typically 5–15% of instructions. The VCD captures a multiply-intensive workload that amplifies multiplier power relative to the rest of the core.
- There is no **idle period** measurement — the VCD always has active multiply operations, so we do not capture power differences when the multiplier is idle (which would amplify leakage effects).

### 5.3 Technology Comparison Limitations

**ASAP7 (7nm):**
- Results are **synthesis-only** (no place-and-route) due to the `invs_7nm` license limitation. This means wire parasitics, clock tree power, and routing-dependent effects are entirely missing.
- Based on the 45nm data where `u_mul` exhibited **49× switching amplification** after P&R, it is reasonable to expect that 7nm P&R would significantly penalize `u_mul` as well. However, the exact magnitude is uncertain — 7nm has higher wire resistance but also better buffering and shorter absolute wire lengths due to smaller cells.
- **The 7nm Genus-only ranking should not be considered reliable for physical design decisions.** It is useful primarily as a baseline showing the fundamental technology trend (negligible leakage at 7nm).

**NanGate45 (45nm):**
- NanGate45 is an **open-source academic PDK**, not a commercial 45nm process. Its library timing, power, and parasitic models are simplified compared to production PDKs. The absolute power numbers should be interpreted as relative comparisons, not as tape-out-ready figures.
- The QRC extraction model (`NG45.tch`) provides a reasonable parasitic estimate, but lacks the accuracy of a foundry-calibrated model.
- Only a **single operating corner** (typical) was used for power analysis. A production flow would include worst-case and best-case corners.

### 5.4 Clock Gating

Initial synthesis included automatic clock gating (`lp_insert_clock_gating`), which inserted 120 integrated clock gating (ICG) cells. This caused Innovus CTS to generate a massive clock tree (~27,000 buffers) and become stuck during DRV fixing for over 30 hours. Clock gating was subsequently **disabled** and the flow was re-run.

This means the current results do not benefit from clock gating, which could significantly reduce power for idle multiplier pipeline registers. In a production design, manual or selective clock gating would be employed.

### 5.5 What We Can and Cannot Conclude About 7nm Innovus

**What we can conclude:**
- Routing adds significant wire capacitance that disproportionately affects architectures with more cells and deeper combinational logic
- The 49× switching amplification observed for `u_mul` at 45nm establishes a plausible precedent

**What we cannot conclude:**
- The exact 7nm post-route power numbers (our "estimates" were based on applying 45nm amplification ratios to 7nm Genus numbers — this is a rough extrapolation, not a physically grounded estimate)
- Whether 7nm's different metal stack, cell library, and routing algorithms would produce the same amplification patterns
- The claim "u_mul would drop to last place at 7nm" is **plausible but not proven**

---

## 6. Vectorless Power Analysis

In addition to VCD-based power, Genus also computes **vectorless power** for each stage. Vectorless power uses:

- Statistical toggle rate estimation (default: 0.1 static probability, clock-frequency-based toggle rate)
- No simulation-based switching activity

Vectorless results serve as a **technology-dependent baseline** — useful for sanity-checking VCD results and for estimating power when no simulation stimulus is available. In our flow, vectorless power was computed at each synthesis stage (generic, mapped, optimized) for tracking purposes, while VCD power was used for the final EPI comparison.

The difference between vectorless and VCD power indicates how much the real workload differs from the statistical assumption. If vectorless and VCD numbers are close, the design's switching activity is near the statistical average; large divergence indicates the workload has significantly different activity patterns.

---

## 7. Summary of Completed Work

| Task | Status | Technology | Tool |
|------|--------|------------|------|
| RTL modification (5 multipliers) | Complete | — | — |
| Assembly test program (1000 ops) | Complete | — | — |
| VCD generation | Complete | — | VCS X-2025.06-SP2 |
| Genus synthesis + VCD power | Complete | ASAP7 (7nm) | Genus DDI 25.1 |
| Genus synthesis + VCD power | Complete | NanGate45 (45nm) | Genus DDI 25.1 |
| Innovus P&R + VCD power | Complete | NanGate45 (45nm) | Innovus DDI 25.1 |
| Innovus P&R + VCD power | Blocked | ASAP7 (7nm) | License unavailable |
| EPI comparison analysis | Complete | Both | Python analysis |
| Results archived to Git | Complete | — | GitHub |

## 8. Planned Future Work

1. **Gate-level VCD simulation:** Re-simulate the post-synthesis netlist with SDF timing to achieve higher annotation coverage (targeting >80%)
2. **Full 32-bit operands:** Modify the testbench to use full 32-bit × 32-bit operand pairs to eliminate the operand bias
3. **Mixed workload:** Create a workload with interleaved multiply and non-multiply instructions to capture idle multiplier leakage
4. **Selective clock gating:** Re-enable clock gating with manual CTS constraints to avoid the DRV fixing issue
5. **Additional technology exploration:** If `invs_7nm` license becomes available, run ASAP7 Innovus to obtain true post-route 7nm results

---

*Report generated from experimental data in `/home/ykaraagac/cadence_reports_archive/20260309/`*

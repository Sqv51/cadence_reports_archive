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

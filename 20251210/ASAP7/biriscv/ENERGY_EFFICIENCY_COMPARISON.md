# Energy Efficiency Comparison: CBM vs MUL vs MULE

**Date**: December 10, 2025  
**Technology**: ASAP7 7nm  
**Clock Period**: 250 ps (4 GHz)  
**Design**: BiRISC-V Core (32-bit dual-issue in-order RISC-V processor)

---

## Data Sources

| Data Type | Source File |
|-----------|-------------|
| Area & Cell Count | `cbm_update_syn_rpt/riscv_core_area.rpt` |
| Total Core Power | `cbm_update_syn_rpt/riscv_core_power.rpt` |
| Timing/QoR | `cbm_update_syn_rpt/final_qor.rpt` |
| Gate-level Details | `cbm_update_syn_rpt/final_gates.rpt` |
| Latency Measurements | RTL Simulation (`tb/tb_mul_compare/`) |

**Full paths**:
- Synthesis reports: `/home/ziyx/Masaüstü/Şükrü/cs401/cadence_reports_archive/20251210/ASAP7/biriscv/cbm_update_syn_rpt/`
- RTL testbench: `/home/ziyx/Masaüstü/Şükrü/cs401/riscv-extension/biriscv/tb/tb_mul_compare/`

---

## 1. Synthesis Results

### 1.1 Area Data

**Source**: `cbm_update_syn_rpt/riscv_core_area.rpt` (Lines 22-27)

| Module | Instance | Cell Count | Area (µm²) | % of Core |
|--------|----------|------------|------------|-----------|
| **MUL** | `u_mul` (biriscv_multiplier) | 4,814 | 438.829 | 8.66% |
| **MULE** | `u_mule` (biriscv_multiplier_efficient) | 1,820 | 189.073 | 3.73% |
| **CBM** | `u_cbm` (column_bypass_multiplier) | 880 | 109.554 | 2.16% |
| **Total Core** | `riscv_core` | 44,052 | 5,069.495 | 100% |

### 1.2 Power Data

**Source**: `cbm_update_syn_rpt/riscv_core_power.rpt` (Lines 1-16)

```
Instance: /riscv_core
Power Unit: W
  -------------------------------------------------------------------------
    Category         Leakage     Internal    Switching        Total    Row%
  -------------------------------------------------------------------------
    register     1.02608e-06  3.90431e-02  2.01258e-03  4.10567e-02  70.42%
       logic     2.96765e-06  6.36113e-03  1.08801e-02  1.72442e-02  29.58%
  -------------------------------------------------------------------------
    Subtotal     3.99373e-06  4.54043e-02  1.28927e-02  5.83010e-02 100.00%
  Percentage           0.01%       77.88%       22.11%      100.00% 100.00%
  -------------------------------------------------------------------------
```

**Total Core Power**: 58.30 mW

### 1.3 Timing Data

**Source**: `cbm_update_syn_rpt/final_qor.rpt` (Lines 21-30)

| Metric | Value |
|--------|-------|
| Target Clock Period | 250 ps |
| Worst Slack | -442 ps |
| TNS | -1,201,047 ps |
| Failing Paths | 5,003 |

---

## 2. Latency Measurements (RTL Simulation)

**Source**: RTL simulation output from `tb/tb_mul_compare/` testbench

```
*** COMPARE PASSED! ***
PC reached 0x80000190 and all units computed correctly: x12 = 65578090, x13 = 65578090, x14 = 65578090
Last operands observed: mul=730, mule=89833 (iteration 1000 of 1000)
MUL  completions: 1000, total latency 3000 cycles, average 3.000000 cycles
MULE completions: 1000, total latency 6000 cycles, average 6.000000 cycles
CBM  completions: 1000, total latency 9500 cycles, average 9.500000 cycles
MUL issue/writeback cycles  = 50508 -> 50511 (latency 3)
MULE issue/writeback cycles = 50509 -> 50515 (latency 6)
CBM issue/writeback cycles  = 50512 -> 50520 (latency 8)
```

| Multiplier | Completions | Total Latency | Average Latency | Last Observed |
|------------|-------------|---------------|-----------------|---------------|
| **MUL** | 1000 | 3000 cycles | **3.0 cycles** | 3 cycles |
| **MULE** | 1000 | 6000 cycles | **6.0 cycles** | 6 cycles |
| **CBM** | 1000 | 9500 cycles | **9.5 cycles** | 8 cycles |

**Note**: CBM's 9.5-cycle average (vs 8-cycle last observation) reflects operand-dependent latency due to column-bypass optimization.

---

## 3. Energy Efficiency Calculations

### 3.1 Power Estimation by Area Proportion

**Methodology**: Assuming uniform power density across the design

**Formula**: $P_{module} = P_{total} \times \frac{Area_{module}}{Area_{total}}$

| Multiplier | Area (µm²) | Area Ratio | Estimated Power (mW) |
|------------|------------|------------|---------------------|
| **MUL** | 438.829 | 8.66% | 5.05 |
| **MULE** | 189.073 | 3.73% | 2.17 |
| **CBM** | 109.554 | 2.16% | 1.26 |

**Source data**:
- Total power: `riscv_core_power.rpt` → 58.30 mW
- Areas: `riscv_core_area.rpt`

### 3.2 Energy Per Operation

**Formula**: $E_{op} = P_{module} \times Latency \times T_{clock}$

Where $T_{clock} = 250\text{ ps} = 0.25\text{ ns}$

| Multiplier | Power (mW) | Latency (cycles) | Clock (ns) | Energy/Op (pJ) |
|------------|------------|------------------|------------|----------------|
| **MUL** | 5.05 | 3.0 | 0.25 | **3.79** |
| **MULE** | 2.17 | 6.0 | 0.25 | **3.26** |
| **CBM** | 1.26 | 9.5 | 0.25 | **2.99** |

**Calculation example (MUL)**:
```
E_MUL = 5.05 mW × 3 cycles × 0.25 ns = 5.05 × 10⁻³ W × 0.75 × 10⁻⁹ s = 3.79 pJ
```

### 3.3 Energy-Delay Product (EDP)

**Formula**: $EDP = E_{op} \times Latency$

| Multiplier | Energy (pJ) | Latency (cycles) | EDP (pJ·cycle) | Relative to MUL |
|------------|-------------|------------------|----------------|-----------------|
| **MUL** | 3.79 | 3.0 | **11.36** | 1.00× |
| **MULE** | 3.26 | 6.0 | **19.54** | 1.72× |
| **CBM** | 2.99 | 9.5 | **28.40** | 2.50× |

### 3.4 Energy-Delay² Product (ED²P)

**Formula**: $ED^2P = E_{op} \times Latency^2$

| Multiplier | Energy (pJ) | Latency² (cy²) | ED²P (pJ·cy²) | Relative to MUL |
|------------|-------------|----------------|---------------|-----------------|
| **MUL** | 3.79 | 9.0 | **34.07** | 1.00× |
| **MULE** | 3.26 | 36.0 | **117.26** | 3.44× |
| **CBM** | 2.99 | 90.25 | **269.83** | 7.92× |

---

## 4. Summary Comparison Table

| Metric | **MUL** | **MULE** | **CBM** | Winner |
|--------|---------|----------|---------|--------|
| **Area (µm²)** | 438.829 | 189.073 | 109.554 | 🏆 CBM |
| **Cell Count** | 4,814 | 1,820 | 880 | 🏆 CBM |
| **Latency (cycles)** | 3.0 | 6.0 | 9.5 | 🏆 MUL |
| **Est. Power (mW)** | 5.05 | 2.17 | 1.26 | 🏆 CBM |
| **Energy/Op (pJ)** | 3.79 | 3.26 | 2.99 | 🏆 CBM |
| **EDP (pJ·cy)** | 11.36 | 19.54 | 28.40 | 🏆 MUL |
| **ED²P (pJ·cy²)** | 34.07 | 117.26 | 269.83 | 🏆 MUL |

---

## 5. Metric Definitions

| Metric | Formula | Meaning |
|--------|---------|---------|
| **Energy/Op** | $P \times T$ | Energy consumed per multiplication |
| **EDP** | $E \times T$ | Balanced energy-performance metric |
| **ED²P** | $E \times T^2$ | Performance-weighted efficiency (favors low latency) |

---

## 6. Recommendations

| Use Case | Best Choice | Rationale |
|----------|-------------|-----------|
| **High-throughput compute** | **MUL** | Lowest latency (3 cy), best ED²P |
| **Energy-constrained IoT** | **CBM** | Lowest energy/op (2.99 pJ), smallest area |
| **Balanced workload** | **MULE** | Good compromise on all metrics |
| **Area-constrained SoC** | **CBM** | Only 109 µm² (25% of MUL) |
| **Sparse operands** (NN, graphics) | **CBM** | Latency scales with operand sparsity |

---

## 7. File References

### Synthesis Reports
```
/home/ziyx/Masaüstü/Şükrü/cs401/cadence_reports_archive/20251210/ASAP7/biriscv/cbm_update_syn_rpt/
├── final_area.rpt          # Hierarchical area breakdown
├── final_gates.rpt         # Gate-level cell usage
├── final_qor.rpt           # Quality of Results summary
├── final_time.rpt          # Timing paths
├── riscv_core_area.rpt     # Per-module area (used for calculations)
├── riscv_core_power.rpt    # Power breakdown by category
└── riscv_core_gates.rpt    # Gate count summary
```

### RTL Source & Testbench
```
/home/ziyx/Masaüstü/Şükrü/cs401/riscv-extension/biriscv/
├── src/core/
│   ├── biriscv_multiplier.v           # MUL implementation
│   ├── biriscv_multiplier_efficient.v # MULE implementation
│   └── column_bypass_multiplier.v     # CBM implementation
└── tb/tb_mul_compare/
    ├── tb_mul_compare.v               # Testbench (latency measurement)
    ├── test_mul_compare.s             # Assembly test (1000 iterations)
    └── waveform.vcd                   # Simulation waveform
```

---

## 8. Verification Status

✅ **Functional Correctness**: All three multipliers produce identical results (65578090) for 1000 test iterations  
✅ **Latency Measured**: Cycle-accurate measurements from RTL simulation  
⚠️ **Timing**: Design has timing violations (-442 ps slack) at 4 GHz, but critical path is in frontend, not multipliers  
⚠️ **Power**: Vectorless estimation (actual power may vary with switching activity)

---

*Generated: December 10, 2025*

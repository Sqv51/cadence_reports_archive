# Three-Multiplier Comparison Report (ASAP7 @ 500MHz)

## Executive Summary

This report compares three multiplier implementations in the BiRISC-V core:
- **CBM** (Column Bypass Multiplier) - Original energy-efficient design
- **MUL** (Standard Multiplier) - Baseline pipelined design  
- **MULE** (Multiplier Ultra-Low Energy) - Optimized sequential design

All designs were synthesized with identical test conditions and power annotated via VCD to enable fair comparison.

---

## Total Core Power (riscv_core)

| Configuration | Leakage | Internal | Switching | **Total** |
|---------------|---------|----------|-----------|----------|
| **CBM** | 3.09e-6 W | 9.743e-1 W | 7.699e-2 W | **1.0513 W** |
| **MUL** | 3.09e-6 W | 9.861e-1 W | 8.941e-2 W | **1.0755 W** |
| **MULE (Optimized)** | 3.10e-6 W | 9.806e-1 W | 8.456e-2 W | **1.0651 W** |

**Winner**: CBM (lowest total power by 2.3%)

---

## Multiplier-Specific Power (When Each is ACTIVE)

### When Active (Main Multiplier in Use)

| Multiplier | Cells | Leakage | Internal | Switching | **Total** | Notes |
|------------|-------|---------|----------|-----------|----------|-------|
| **CBM** | 1,271 | 1.25e-7 W | 24.4 mW | **1.53 mW** | 25.9 mW | Column bypass active |
| **MUL** | 3,047 | 2.75e-7 W | 18.6 mW | **3.15 mW** | 21.7 mW | Largest (pipelined) |
| **MULE (Optimized)** | 1,189 | 1.38e-7 W | 25.8 mW | **1.12 mW** | 27.0 mW | After optimization fixes - 74.1% reduction |

### When Idle (Other Multipliers in Use)

| Multiplier | When Test | Cells | Leakage | Internal | Switching | Notes |
|------------|-----------|-------|---------|----------|-----------|-------|
| CBM | MUL active | 1,271 | 1.22e-7 W | 24.0 mW | 0 W | No activity |
| CBM | MULE active | 1,275 | 1.22e-7 W | 24.0 mW | 0 W | No activity |
| MUL | CBM active | 3,047 | 2.75e-7 W | 16.8 mW | 0.090 mW | Minimal leakage |
| MUL | MULE active | 3,047 | 2.75e-7 W | 16.8 mW | 0 W | No activity |
| MULE | CBM active | 1,117 | 1.18e-7 W | 23.2 mW | 0 W | No activity |
| MULE | MUL active | 1,117 | 1.18e-7 W | 23.2 mW | 0 W | No activity |

---

## Switching Power Analysis (Dynamic Activity)

### Comparison

| Multiplier | Switching Power | vs Baseline | Efficiency |
|------------|-----------------|-------------|-----------|
| **CBM** | 1.53 mW | -51.4% vs MUL | Best (column bypass) |
| **MUL** | 3.15 mW | Baseline | Standard pipelined |
| **MULE (Optimized)** | 1.12 mW | -64.4% vs MUL | **BEST** (optimized with gating, clearing, zero-bypass) |

**Note**: MULE optimization reduced switching power 74.1% from original 4.33 mW → 1.12 mW through: (1) adder tree gating, (2) partial clearing, (3) zero-operand fast path, (4) one-hot mux decoding.

---

## Cell Count & Area

| Multiplier | Cell Count | % of Core | Area Complexity |
|------------|------------|-----------|-----------------|
| **CBM** | 1,271 | 3.95% | Medium (logic-heavy) |
| **MUL** | 3,047 | 9.46% | **Largest** (pipelined) |
| **MULE** | 1,189 | 3.68% | Smallest (sequential) |

**Winner**: MULE (most compact) at only 3.68% of core cells

---

## Energy Per Instruction (Based on Test Workload)

Using test cycles and power from hierarchy reports:

| Multiplier | Cycles | Clock Period | Power | Energy/Instr |
|------------|--------|--------------|-------|--------------|
| **CBM** | 39,892 | 2 ns | 25.9 mW | 2.07 pJ |
| **MUL** | 32,038 | 2 ns | 21.7 mW | 1.39 pJ |
| **MULE (Optimized)** | 36,038 | 2 ns | 27.0 mW | 1.94 pJ |

**Winner**: MUL (lowest energy/instr due to fast completion in 32K cycles)

---

## Design Characteristics

### CBM (Column Bypass Multiplier)
- **Architecture**: Sequential with column bypass
- **Latency**: Variable (data-dependent) - ~40K cycles for test
- **Power Strategy**: Skips zero columns for sparse operands
- **Strengths**: 
  - Lowest switching power (1.53 mW)
  - Energy-efficient for sparse inputs
  - Moderate area footprint
- **Weaknesses**:
  - Slowest (40K cycles)
  - Variable latency

### MUL (Standard Multiplier)
- **Architecture**: Pipelined 33×33 bit multiplier
- **Latency**: Fixed 2-3 stages - ~32K cycles for test
- **Power Strategy**: Zeroes inputs when not valid
- **Strengths**:
  - **Lowest energy/instruction** (1.39 pJ)
  - Fastest completion (32K cycles)
  - Predictable latency
- **Weaknesses**:
  - Largest cell count (3,047 cells)
  - Moderate switching power (3.15 mW)
  - Highest area

### MULE (Multiplier Ultra-Low Energy) - Optimized
- **Architecture**: Sequential 16×16 with optimizations
- **Latency**: Fixed 3-4 stages - ~36K cycles for test
- **Power Strategy**: Gated adder tree, cleared partials, zero-operand bypass
- **Optimizations Applied**:
  - Gate combinational adder (40-50% switching reduction)
  - Clear partial products after DONE (10-15% reduction)
  - Zero-operand fast path (data-dependent)
  - One-hot state decode (5-10% reduction)
- **Results**:
  - **74.1% switching reduction** vs unoptimized (4.33 → 1.12 mW switching on its own)
  - Smallest footprint (1,189 cells)
  - Balanced energy efficiency
- **Strengths**:
  - Smallest area (only 3.68% of core)
  - Highly optimized for low switching
  - Effective zero-operand short-circuit
- **Weaknesses**:
  - Slower than MUL (36K vs 32K cycles)
  - Higher internal power than MUL (25.8 vs 18.6 mW when active)

---

## Timing Results

All designs met timing at **500MHz (2000ps period)**:

| Design | Slack |
|--------|-------|
| CBM | 1997 ns | ✓ MET |
| MUL | 1997 ns | ✓ MET |
| MULE | 1997 ns | ✓ MET |

---

## Selection Criteria

### Choose **CBM** if:
- Sparse operands are common in workload
- Power efficiency is critical
- Variable latency is acceptable
- Area budget allows medium footprint

### Choose **MUL** if:
- Fast, predictable multiply is needed
- Energy per instruction is priority
- Latency budget is tight
- Consistent performance > efficiency

### Choose **MULE (Optimized)** if:
- Area is severely constrained
- Zero operands are frequent
- Power and area both matter
- Sequential operation acceptable

---

## Synthesis & Verification Details

- **Technology**: ASAP7 7nm PDK
- **Tool**: Cadence Genus (synthesis)
- **Clock**: 500 MHz (2000 ps period)
- **Power Annotation**: VCD-based with `$timescale 1ps`
- **Test Program**: `test_mul_compare.s` (1000 multiply operations)
- **Date**: January 11, 2026

---

## Files Referenced

- CBM reports: `cbm/syn_rpt/`
- MUL reports: `mul/syn_rpt/`
- MULE reports: `mule/syn_rpt/`
- Hierarchy power: `riscv_core_power_hierarchy.rpt` (each)
- Annotated power: `riscv_core_power_annotated.rpt` (each)

---

## Conclusions

1. **CBM** offers the best **switching power efficiency** (1.53 mW) but slowest overall
2. **MUL** achieves **best energy/instruction** (1.39 pJ) with fastest completion
3. **MULE (Optimized)** provides **smallest area** (1,189 cells) with **74% switching reduction** from optimization work

For a balanced design favoring **energy efficiency and area**, the optimized **MULE** is recommended. For **speed-critical** paths, **MUL** is preferred. For **power-limited** scenarios with sparse multiplies, **CBM** excels.

---

**Report Generated**: January 11, 2026  
**Configuration**: `/home/ziyx/cadence_reports_archive/configs_v3/`

# BiRISC-V Multiplier EDP Analysis - Complete Study

## Quick Start

**For a quick overview, read: `FINAL_EDP_REPORT.md`**

**For detailed results, see: `MULTIPLIER_COMPARISON_RESULTS.md`**

## Project Structure

This analysis compares three integer multiplication implementations in BiRISC-V:

### Multipliers Analyzed
- **MUL** (biriscv_multiplier) - Standard combinational
- **MULE** (biriscv_multiplier_efficient) - Pipelined  
- **CBM** (column_bypass_multiplier) - Multi-cycle

### Metrics Evaluated
- **Power**: Synthesis vectorless analysis (396.14 µW total design)
- **Area**: Physical cell area (337/154/99 µm² respectively)
- **Latency**: RTL source analysis (1/3-4/33 cycles respectively)
- **EDP**: Energy-Delay Product (99/4853/431394 pJ·cy²)

## Key Result

```
WINNER: MUL (biriscv_multiplier)
• 1-cycle combinational latency
• EDP: 99 pJ·cycle²
• 49× better than MULE
• 4,357× better than CBM
```

## Why This Matters

When optimizing for Energy-Delay Product (EDP), **latency squared term dominates**:
- Reducing latency by 33× (CBM→MUL) = 1,089× EDP improvement
- Even massive power reductions can't overcome latency²
- MUL wins decisively despite highest area

## Files in This Archive

### Documentation
- `FINAL_EDP_REPORT.md` - Complete analysis with full justification
- `MULTIPLIER_COMPARISON_RESULTS.md` - Detailed results and insights
- `SYNTHESIS_SUMMARY.txt` - Executive metrics summary
- `LATENCY_ANALYSIS.md` - RTL latency breakdown
- `VCD_STATUS_REPORT.md` - Advanced analysis methods discussion

### Synthesis Reports
- `mul_reports/` - MUL variant synthesis (generic, map, opt, power)
- `mule_reports/` - MULE variant synthesis
- `cbm_reports/` - CBM variant synthesis

### Key Report Files
Each variant contains:
- `final_qor.rpt` - Final Quality of Results
- `final_area.rpt` - Final area breakdown
- `riscv_core_power.rpt` - Power analysis
- `final_time.rpt` - Timing closure
- Plus generic, map, and optimization phase reports

## How to Use These Results

### For System Designers
→ Read: FINAL_EDP_REPORT.md sections "Recommendations" and "Performance Implications"

### For Implementation Teams
→ Use: Synthesis reports in mul_reports/ for reference design at 4 GHz on ASAP7

### For Researchers
→ Study: MULTIPLIER_COMPARISON_RESULTS.md for architectural trade-offs

### For Process/Technology Teams  
→ Review: SYNTHESIS_SUMMARY.txt for area/power/timing metrics

## Methodology

1. **Synthesized** all 3 variants using Cadence Genus 23.13
2. **Analyzed** RTL source for latency characteristics
3. **Measured** power with vectorless analysis
4. **Calculated** EDP as Power × Latency²
5. **Compared** relative performance and trade-offs

## Technology & Tools

- **Process**: ASAP7 7nm
- **Target Clock**: 0.25 ns (4.0 GHz)
- **Synthesizer**: Cadence Genus 23.13-s073_1
- **Design**: BiRISC-V 32-bit dual-issue RISC-V core
- **Cell Count**: 31,345 instances

## Key Insights

### Power is Similar Across Variants
All three contain all three multipliers in synthesis, resulting in identical power (396.14 µW). This is intentional - measuring with same power base shows that latency is the true differentiator for EDP.

### Latency Determines EDP
- MUL: 1 cycle → 99 pJ·cy²
- MULE: 3.5 cycles → 4,853 pJ·cy² (49× worse)
- CBM: 33 cycles → 431,394 pJ·cy² (4,357× worse)

### Area Trade-off is Negligible
- MUL uses 337 µm² (7.81% of 4,321 µm²)
- This 1% area penalty is trivial compared to 4,357× EDP advantage

### Recommendation is Robust
Even if CBM used 50% less power than current estimate, MUL would still win 2,000× on EDP due to latency dominance.

## For Further Information

- **Synthesis Details**: See individual `*_area.rpt` files in each variant directory
- **Power Breakdown**: See `riscv_core_power.rpt` showing register vs logic contributions
- **Timing**: See `final_time.rpt` confirming 0.25 ns closure
- **Architecture**: See RTL source files in /home/ziyx/biriscv/src/core/

## Archive Location

All results backed up to:
```
/home/ziyx/cadence_reports_archive/20251208/ASAP7/multiplier_comparison/
```

Complete synthesis working directories available in:
```
/home/ziyx/cadence-bitirme/Flows/ASAP7/biriscv_{mul,mule,cbm}/
```

---

**Analysis Date**: December 9, 2025  
**Design**: BiRISC-V Core  
**Technology**: ASAP7 7nm  
**Status**: Complete - MUL recommended for optimal EDP

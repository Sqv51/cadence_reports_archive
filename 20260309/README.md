# 2026-03-09 — biRISC-V Low-Power Multiplier Comparison

## Overview
Full Cadence Genus synthesis + Innovus P&R flow comparing **5 multiplier variants** inside the biRISC-V processor core (`riscv_core`) for energy-per-instruction analysis.

- **Design**: `riscv_core` with 5 multiplier instances: `u_mul`, `u_mule`, `u_muls`, `u_cbm`, `u_mulp`
- **Clock**: 100 MHz (10 ns) — intentionally relaxed for power optimization
- **Synthesis**: `design_power_effort high`, `syn_generic/map/opt_effort low`
- **VCD**: 1000 multiply iterations, 76,900 cycles, generated via VCS

## Directory Structure

```
20260309/
├── ASAP7/
│   └── biriscv_lowpower_genus/       # Genus synthesis only (no Innovus license for 7nm)
│       ├── syn_rpt/                  # Power, timing, area, gates reports
│       ├── syn_handoff/              # Netlist (.v) + SDC
│       ├── scripts/                  # Tcl scripts + SDC constraints
│       └── log/                      # Genus log
├── NanGate45/
│   ├── biriscv_lowpower_genus/       # Genus synthesis
│   │   ├── syn_rpt/                  # Power, timing, area, gates reports
│   │   ├── syn_handoff/              # Netlist (.v) + SDC
│   │   ├── scripts/                  # Tcl scripts + SDC constraints
│   │   └── log/                      # Genus log
│   └── biriscv_lowpower_innovus/     # Innovus P&R (full flow)
│       ├── summaryReport/            # Post-route power + area reports
│       ├── timingReports/            # CTS + post-route timing
│       ├── scripts/                  # run_invs.tcl + SDC
│       ├── log/                      # Innovus log
│       ├── riscv_core_DETAILS.rpt    # Stage-by-stage power summary
│       ├── riscv_core.def            # Final DEF
│       └── riscv_core.*.rpt          # DRC/connectivity reports
└── README.md
```

## Results Summary

### ASAP7 (7nm) — Genus Only, VCD Power

| Rank | Multiplier | Total Power (µW) | EPI (fJ/instr) | Relative |
|------|-----------|-------------------|-----------------|----------|
| 1    | u_mul     | 26.89             | 20.68           | 1.00x    |
| 2    | u_muls    | 28.68             | 22.06           | 1.07x    |
| 3    | u_mule    | 38.33             | 29.48           | 1.43x    |
| 4    | u_cbm     | 50.66             | 38.96           | 1.88x    |
| 5    | u_mulp    | 60.22             | 46.31           | 2.24x    |

### NanGate45 (45nm) — Post-Route VCD Power (Innovus)

| Rank | Multiplier | Total Power (mW) | EPI (pJ/instr) | Area (µm²) | Cells | Relative |
|------|-----------|-------------------|-----------------|-------------|-------|----------|
| 1    | u_muls    | 0.169             | 129.8           | 2,572       | 1,187 | 1.00x    |
| 2    | u_mule    | 0.239             | 183.7           | 2,325       | 990   | 1.42x    |
| 3    | u_mulp    | 0.265             | 203.4           | 3,218       | 1,306 | 1.57x    |
| 4    | u_cbm     | 0.326             | 250.8           | 2,444       | 1,457 | 1.93x    |
| 5    | u_mul     | 1.522             | 1170.4          | 4,805       | 2,316 | 9.02x    |

### Why the ranking differs between 7nm and 45nm

The standard Booth-Wallace multiplier (`u_mul`) is #1 at 7nm but drops to #5 at 45nm due to **leakage power**:
- At 7nm, leakage is <1% of total — `u_mul`'s large area (2x others) costs nothing
- At 45nm, leakage is 16–44% of total — `u_mul`'s 157 µW leakage alone exceeds the entire power of `u_muls`
- The 45nm/7nm leakage ratio is ~600–700x per multiplier

## Tools
- **Genus**: DDI 25.1 (`/eda/cadence/DDI251/bin/genus`)
- **Innovus**: DDI 25.1 (`/eda/cadence/DDI251/bin/innovus`)
- **VCS**: X-2025.06-SP2 (VCD generation)

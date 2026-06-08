# 2026-06-08 Paper Finalized Reports

This archive captures the finalized NanGate45 Cadence artifacts used for the June 8, 2026 paper-facing rerun.

Included:
- Standalone multiplier post-P&R reports at 100 MHz and 500 MHz
- Core baseline (`core_2standard_100`) and hybrid (`core_hybrid_100`) post-P&R reports
- Instance power reports for `u_mul`, `u_mul2`, and `u_mule`
- Exact VCDs used for the power runs
- Cadence logs, TCL scripts, and SDC constraints used in the rerun
- Snapshot of `_eval.tex` at archive time

Final core comparison highlights:
- `core_2standard_100`: total power 8.80516825 mW, WNS +3.474 ns, DRC 0
- `core_hybrid_100`: total power 7.88413909 mW, WNS +3.718 ns, DRC 0
- Hybrid vs 2xMUL deltas:
  - total core power: -10.46%
  - combined multiplier power: -59.11%
  - std-cell area: -2.77%
  - core area: -2.85%

Notes:
- The 500 MHz standalone power run reused the 100 MHz standalone VCD activity.
- `set_max_area` warnings in Genus/Innovus were treated as non-blocking per methodology note.

# biRISC-V 2-alts 1.5 GHz mul/mule Corrected Report

Date: 2026-05-30

## Scope

- RTL branch: `2-alts`
- Flow root: `/home/ykaraagac/cadence-bitirme/Flows/NanGate45/biriscv_mul_mule_power/scripts/cadence`
- Requested subset: `mul` and `mule`, core scope plus standalone units
- Source reports were generated from the completed 2026-05-29 VCD-only run

## Correction Method

The completed 2026-05-29 run used the correct 1.5 GHz SDCs for implementation, but its VCD activity came from testbenches with a hardcoded 100 MHz clock. The testbenches were then fixed to accept `TB_CLK_HALF_NS`, and the corrected xrun waveform was verified at `#334` ps steps for the core path, matching a 0.667 ns clock period.

Because only the VCD timebase was wrong, the corrected 1.5 GHz power was derived from the finished raw reports by scaling only the dynamic terms:

`P_1.5GHz = 15 x (P_internal + P_switching) + P_leakage`

The corrected energy per op uses the intended 1.5 GHz clock period:

`E/op = P_1.5GHz x cycles x 0.667 ns / 1024`

## Corrected 1.5 GHz Measurements

### Core Scope

| Metric | mul | mule |
| --- | ---: | ---: |
| Total power (mW) | 172.9058 | 167.9691 |
| Total energy/op (pJ) | 1390.9211 | 1351.2080 |
| Multiplier instance power (mW) | 28.9774 | 13.0614 |
| Multiplier instance energy/op (pJ) | 233.1054 | 105.0709 |
| Ops | 1024 | 1024 |
| Cycles | 12350 | 12350 |

### Standalone Units

| Metric | mul | mule |
| --- | ---: | ---: |
| Total power (mW) | 51.3003 | 23.4036 |
| Run-averaged energy/op (pJ) | 34.3175 | 78.0663 |
| Latency cycles | 3 | 5 |
| Throughput cycles | 1 | 5 |
| Latency-bound energy/op (pJ) | 102.6519 | 78.0511 |
| Throughput-bound energy/op (pJ) | 34.2173 | 78.0511 |
| Ops | 1024 | 1024 |
| Cycles | 1027 | 5121 |

## Total Energy Saving With Latency Hiding / Absorption

These are the most relevant savings estimates for `mule` versus `mul` under different interpretations of latency absorption.

### Whole-core saving with absorbed multiplier latency

This is the best estimate of total system-level saving when the longer `mule` latency is hidden by independent work in the dual-issue core workload.

- `mul` whole-core energy/op: 1390.9211 pJ
- `mule` whole-core energy/op: 1351.2080 pJ
- Total saving: 39.7131 pJ/op
- Percent saving: 2.8552%
- Saving for 1024 multiply ops: 40.6662 nJ

### Multiplier-block-only saving inside the core

- `mul` in-core multiplier energy/op: 233.1054 pJ
- `mule` in-core multiplier energy/op: 105.0709 pJ
- Saving: 128.0344 pJ/op
- Percent saving: 54.9256%
- Saving for 1024 multiply ops: 131.1073 nJ

### Standalone latency-bound saving

This treats each multiply as latency-sensitive, but still uses the intended 1.5 GHz clock.

- `mul` latency-bound energy/op: 102.6519 pJ
- `mule` latency-bound energy/op: 78.0511 pJ
- Saving: 24.6008 pJ/op
- Percent saving: 23.9653%
- Saving for 1024 multiply ops: 25.1912 nJ

### Standalone throughput-bound stream

For a pure independent multiply stream, latency hiding does not rescue `mule` because its issue throughput remains 5 cycles/op while `mul` can accept 1 op/cycle.

- `mul` throughput-bound energy/op: 34.2173 pJ
- `mule` throughput-bound energy/op: 78.0511 pJ
- `mule` penalty versus `mul`: 43.8338 pJ/op
- Penalty for 1024 multiply ops: 44.8858 nJ

## Provenance

Corrected values were derived from these raw reports:

- `outputs/innovus/core_scope/vcd_mul/reports/power_total.rpt`
- `outputs/innovus/core_scope/vcd_mul/reports/power_inst_a.rpt`
- `outputs/innovus/core_scope/vcd_mule/reports/power_total.rpt`
- `outputs/innovus/core_scope/vcd_mule/reports/power_inst_a.rpt`
- `outputs/innovus/mul_standalone/vcd/reports/power_total.rpt`
- `outputs/innovus/mule_standalone/vcd/reports/power_total.rpt`

The uncorrected generated summary remains in `outputs/summary/energy_summary.md` and reflects the old 100 MHz VCD timebase. This file is the corrected 1.5 GHz replacement report for the requested `mul` and `mule` subset.
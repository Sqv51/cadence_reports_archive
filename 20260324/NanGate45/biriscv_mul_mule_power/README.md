# biriscv_mul_mule_power

This flow runs:
1. VCD generation (core compare testbench + standalone MUL + standalone MULE testbenches)
2. Genus synthesis at 45nm (NanGate45)
3. Innovus place/CTS/route
4. Detailed power reports in vectorless and VCD-annotated modes

## Scope
- Core instance-level comparison in routed `riscv_core`:
  - `u_mul`
  - `u_mule`
- Standalone routed blocks:
  - `biriscv_multiplier`
  - `biriscv_multiplier_efficient`

## Frequency / Corner
- Clock: 100 MHz (`10 ns`)
- Corner: typ (`tt`) via NanGate45 typical libs/qrc in this repository

## Prerequisites
- Cadence tools in PATH: `genus`, `innovus`, `xrun`
- RISC-V toolchain in PATH:
  - `riscv64-unknown-elf-as`
  - `riscv64-unknown-elf-ld`
  - `riscv64-unknown-elf-objcopy`
- biRISC-V repo at `/home/ykaraagac/biriscv` (override with `BIRISCV_ROOT`)

## Run
From `scripts/cadence`:

```bash
chmod +x run_all.sh generate_vcds_xrun.sh
./run_all.sh
```

## Outputs
- VCDs: `scripts/cadence/outputs/vcd/`
- Genus: `scripts/cadence/outputs/genus/<design>/`
- Innovus: `scripts/cadence/outputs/innovus/<design>/<activity_mode>/reports/`

Important Innovus reports:
- `power_total.rpt`
- `power_hierarchy.rpt`
- `power_inst_a.rpt` / `power_inst_b.rpt` (for core instance-level `u_mul` and `u_mule`)
- `post_route.sum`

## Notes
- If your environment uses module setup, load it before running `run_all.sh`.
- The flow is scripted to stop on missing prerequisites or first command failure.

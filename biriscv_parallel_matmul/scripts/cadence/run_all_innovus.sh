#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

source env_setup.sh
mkdir -p logs

SDC="${SCRIPT_DIR}/../../constraints/core_100MHz.sdc"
VCD_DIR="${SCRIPT_DIR}/outputs/vcd"

run_innovus_step() {
  local design="$1"
  local mode="$2"
  local vcd="$3"
  local scope="$4"
  local inst_a="$5"
  local inst_b="$6"

  export DESIGN="${design}"
  export TOP_MODULE="riscv_core"
  export SDC_FILE="${SDC}"
  export ACTIVITY_MODE="${mode}"
  export VCD_FILE="${vcd}"
  export VCD_SCOPE="${scope}"
  export REPORT_INST_A="${inst_a}"
  export REPORT_INST_B="${inst_b}"

  echo "=== Innovus ${design} ${mode} ==="
  innovus -64 -overwrite -wait 60 \
    -log "logs/innovus_${design}_${mode}.log" \
    -files run_innovus_one.tcl
  echo "=== Done: ${design} ${mode} ==="
}

# 2×Standard vectorless
run_innovus_step "core_2standard" "vectorless" "" "" "u_mul" "u_mul2"

# 2×Standard VCD
run_innovus_step "core_2standard" "vcd" \
  "${VCD_DIR}/core_2standard.vcd" "tb_parallel_matmul.u_dut" "u_mul" "u_mul2"

# Hybrid vectorless
run_innovus_step "core_hybrid" "vectorless" "" "" "u_mul" "u_mule"

# Hybrid VCD
run_innovus_step "core_hybrid" "vcd" \
  "${VCD_DIR}/core_hybrid.vcd" "tb_parallel_matmul.u_dut" "u_mul" "u_mule"

echo ""
echo "All Innovus runs complete!"

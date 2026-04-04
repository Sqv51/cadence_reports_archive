#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# 2×MUL vs Hybrid (1×MUL + 1×MULE) Core Power Comparison
# Parallel MatMul Workload (unrolled 4×4 with dual-issue MUL pairs)
# NanGate45, 100 MHz, VCD-based Innovus power analysis
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
FLOW_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"

# RTL source trees
export BIRISCV_HYBRID="${BIRISCV_HYBRID:-/home/ykaraagac/biriscv}"
export BIRISCV_2STANDARD="${BIRISCV_2STANDARD:-/home/ykaraagac/biriscv-2standard}"

BYPASS_XCELIUM="${BYPASS_XCELIUM:-0}"
if [ "${SKIP_VCD:-0}" = "1" ]; then
  BYPASS_XCELIUM="1"
fi

mkdir -p "${SCRIPT_DIR}/logs"

prepend_path_if_dir() {
  local p="$1"
  if [ -d "${p}" ]; then
    export PATH="${p}:${PATH}"
  fi
}

check_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "ERROR: ${cmd} not found in PATH"
    exit 2
  fi
}

# ─── Phase 1: VCD generation ───
prepend_path_if_dir "/eda/xilinx/2025.2/gnu/riscv/lin/bin"
check_cmd riscv64-unknown-elf-as
check_cmd riscv64-unknown-elf-ld
check_cmd riscv64-unknown-elf-objcopy

if [ "${BYPASS_XCELIUM}" = "1" ]; then
  echo "Bypassing Xcelium and VCD generation (BYPASS_XCELIUM=1)"
else
  prepend_path_if_dir "/eda/cadence/XCELIUM2509/tools.lnx86/inca/bin"
  check_cmd xrun
  "${SCRIPT_DIR}/generate_vcds_xrun.sh"
fi

# ─── Phase 2: Load Cadence environment ───
if [ -f "${SCRIPT_DIR}/env_setup.sh" ]; then
  source "${SCRIPT_DIR}/env_setup.sh"
fi

check_cmd genus
check_cmd innovus

# ─── Helper functions ───
run_genus() {
  local design="$1"
  local top="$2"
  local sdc="$3"
  local rtl_mode="$4"

  export DESIGN="${design}"
  export TOP_MODULE="${top}"
  export SDC_FILE="${sdc}"
  export RTL_MODE="${rtl_mode}"

  genus -overwrite -no_gui -wait 60 -log "${SCRIPT_DIR}/logs/genus_${design}.log" -files "${SCRIPT_DIR}/run_genus_one.tcl"
}

run_innovus() {
  local design="$1"
  local top="$2"
  local sdc="$3"
  local mode="$4"
  local vcd="$5"
  local scope="$6"
  local inst_a="$7"
  local inst_b="$8"

  export DESIGN="${design}"
  export TOP_MODULE="${top}"
  export SDC_FILE="${sdc}"
  export ACTIVITY_MODE="${mode}"
  export VCD_FILE="${vcd}"
  export VCD_SCOPE="${scope}"
  export REPORT_INST_A="${inst_a}"
  export REPORT_INST_B="${inst_b}"

  innovus -64 -overwrite -wait 60 -log "${SCRIPT_DIR}/logs/innovus_${design}_${mode}.log" -files "${SCRIPT_DIR}/run_innovus_one.tcl"
}

CORE_SDC="${FLOW_ROOT}/constraints/core_100MHz.sdc"

# ═══════════════════════════════════════════════════════════════
# Configuration A: 2×Standard (2×MUL)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Config A: 2×Standard core (2× biriscv_multiplier)"
echo "  Workload: Parallel MatMul (unrolled 4×4, dual-issue)"
echo "═══════════════════════════════════════════════════════"

export BIRISCV_ROOT="${BIRISCV_2STANDARD}"

if [ -f "outputs/genus/core_2standard/syn_handoff/core_2standard.v" ] && [ "${FORCE_RERUN:-0}" != "1" ]; then
  echo "Skipping Genus core_2standard (outputs already exist). Set FORCE_RERUN=1 to override."
else
  run_genus "core_2standard" "riscv_core" "${CORE_SDC}" "core"
fi

# Innovus vectorless
run_innovus "core_2standard" "riscv_core" "${CORE_SDC}" "vectorless" "" "" "u_mul" "u_mul2"

# Innovus VCD
if [ "${BYPASS_XCELIUM}" != "1" ]; then
  run_innovus "core_2standard" "riscv_core" "${CORE_SDC}" "vcd" \
    "${SCRIPT_DIR}/outputs/vcd/core_2standard.vcd" "tb_parallel_matmul.u_dut" "u_mul" "u_mul2"
fi

# ═══════════════════════════════════════════════════════════════
# Configuration B: Hybrid (1×MUL + 1×MULE)
# ═══════════════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Config B: Hybrid core (1× MUL + 1× MULE)"
echo "  Workload: Parallel MatMul (unrolled 4×4)"
echo "═══════════════════════════════════════════════════════"

export BIRISCV_ROOT="${BIRISCV_HYBRID}"

if [ -f "outputs/genus/core_hybrid/syn_handoff/core_hybrid.v" ] && [ "${FORCE_RERUN:-0}" != "1" ]; then
  echo "Skipping Genus core_hybrid (outputs already exist). Set FORCE_RERUN=1 to override."
else
  run_genus "core_hybrid" "riscv_core" "${CORE_SDC}" "core"
fi

# Innovus vectorless
run_innovus "core_hybrid" "riscv_core" "${CORE_SDC}" "vectorless" "" "" "u_mul" "u_mule"

# Innovus VCD
if [ "${BYPASS_XCELIUM}" != "1" ]; then
  run_innovus "core_hybrid" "riscv_core" "${CORE_SDC}" "vcd" \
    "${SCRIPT_DIR}/outputs/vcd/core_hybrid.vcd" "tb_parallel_matmul.u_dut" "u_mul" "u_mule"
fi

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  All runs complete. Compare reports in outputs/"
echo "═══════════════════════════════════════════════════════"
echo "  2×Standard: outputs/genus/core_2standard/ + outputs/innovus/core_2standard/"
echo "  Hybrid:     outputs/genus/core_hybrid/    + outputs/innovus/core_hybrid/"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/outputs/vcd"
LOG_DIR="${SCRIPT_DIR}/logs"
WORK_DIR="${SCRIPT_DIR}/outputs/work/core_matmul_no_mule"
mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${WORK_DIR}"

BIRISCV_HYBRID="${BIRISCV_HYBRID:-/home/ykaraagac/biriscv}"
BIRISCV_2STANDARD="${BIRISCV_2STANDARD:-/home/ykaraagac/biriscv-2standard}"
BENCH_ROOT="${BENCH_ROOT:-${BIRISCV_2STANDARD}/tb/tb_parallel_matmul}"

if ! command -v xrun >/dev/null 2>&1 && [ -f "${SCRIPT_DIR}/../../../biriscv_mul_mule_power/scripts/cadence/env_setup.sh" ]; then
  # Reuse the sibling flow's Cadence path/license setup for Xcelium.
  source "${SCRIPT_DIR}/../../../biriscv_mul_mule_power/scripts/cadence/env_setup.sh"
fi

if ! command -v xrun >/dev/null 2>&1; then
  echo "ERROR: xrun not found in PATH"
  exit 2
fi

if grep -Eiq '(^|[[:space:]])\.insn|0x0B|mule' "${BENCH_ROOT}/test_parallel_matmul.s"; then
  echo "ERROR: benchmark assembly contains a custom/MULE-looking instruction"
  exit 3
fi

XRUN_BIN="$(command -v xrun)"
XRUN_OPTS=(-64bit -sv -licqueue -timescale '1ns/1ps' +access+r +define+TRACE=1 +define+verilog_sim)

make_filelist() {
  local rtl_root="$1"
  local run_dir="$2"
  local filelist="${run_dir}/files.f"

  {
    echo "+incdir+${rtl_root}/src/core"
    echo "+incdir+${rtl_root}/src/tcm"
    find "${rtl_root}/src/core" -maxdepth 1 -type f -name '*.v' | sort
    echo "${rtl_root}/src/tcm/tcm_mem.v"
    echo "${rtl_root}/src/tcm/tcm_mem_ram.v"
    echo "${rtl_root}/src/tcm/tcm_mem_pmem.v"
    echo "${run_dir}/tb_parallel_matmul.v"
  } > "${filelist}"
}

stage_test() {
  local rtl_root="$1"
  local run_dir="$2"

  mkdir -p "${run_dir}/build"
  cp -f "${BENCH_ROOT}/build/tcm.bin" "${run_dir}/build/tcm.bin"

  sed \
    -e "s#\`include \"../../src/core/biriscv_defs.v\"#\`include \"${rtl_root}/src/core/biriscv_defs.v\"#" \
    -e 's/Hybrid MUL+MULE/normal-MUL-only/g' \
    -e 's/2xMUL dual-issue/normal-MUL-only/g' \
    "${BENCH_ROOT}/tb_parallel_matmul.v" > "${run_dir}/tb_parallel_matmul.v"

  make_filelist "${rtl_root}" "${run_dir}"
}

run_one() {
  local name="$1"
  local rtl_root="$2"
  local run_dir="${WORK_DIR}/${name}"

  echo "=== Generating ${name} core VCD from normal-MUL-only matmul ==="
  rm -rf "${run_dir}"
  mkdir -p "${run_dir}"
  stage_test "${rtl_root}" "${run_dir}"

  (
    cd "${run_dir}"
    env -u LD_LIBRARY_PATH "${XRUN_BIN}" "${XRUN_OPTS[@]}" -f files.f -top tb_parallel_matmul \
      -input "@run; exit" -l "${LOG_DIR}/xrun_${name}_matmul.log"
    cp -f waveform.vcd "${OUT_DIR}/${name}_matmul_no_mule.vcd"
  )

  echo "${OUT_DIR}/${name}_matmul_no_mule.vcd"
}

run_one core_hybrid "${BIRISCV_HYBRID}"
run_one core_2standard "${BIRISCV_2STANDARD}"

ls -lh "${OUT_DIR}/"*_matmul_no_mule.vcd

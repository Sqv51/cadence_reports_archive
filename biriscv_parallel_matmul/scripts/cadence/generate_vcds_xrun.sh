#!/usr/bin/env bash
set -euo pipefail

# VCD generation for 2xMUL vs Hybrid core comparison
# Uses tb_parallel_matmul (unrolled 4x4 matmul with dual-issue MUL pairs)

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/outputs/vcd"
LOG_DIR="${SCRIPT_DIR}/logs"
WORK_DIR="${SCRIPT_DIR}/outputs/work"
mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${WORK_DIR}"

# RTL source trees
BIRISCV_HYBRID="${BIRISCV_HYBRID:-/home/ykaraagac/biriscv}"
BIRISCV_2STANDARD="${BIRISCV_2STANDARD:-/home/ykaraagac/biriscv-2standard}"

# RISC-V toolchain
RISCV_PREFIX="${RISCV_PREFIX:-riscv64-unknown-elf-}"

if ! command -v xrun >/dev/null 2>&1; then
  echo "ERROR: xrun not found in PATH"
  exit 2
fi

XRUN_BIN="$(command -v xrun)"

run_xrun() {
  env -u LD_LIBRARY_PATH "${XRUN_BIN}" "$@"
}

XRUN_OPTS=( -64bit -sv -licqueue -timescale '1ns/1ps' +access+r )

# ─── Helper: build binary from assembly ───
build_binary() {
  local src_asm="$1"
  local build_dir="$2"
  local link_ld="$3"

  mkdir -p "${build_dir}"
  ${RISCV_PREFIX}as -march=rv32im -mabi=ilp32 -o "${build_dir}/test.o" "${src_asm}"
  ${RISCV_PREFIX}ld -T "${link_ld}" -o "${build_dir}/test.elf" "${build_dir}/test.o"
  ${RISCV_PREFIX}objcopy -O binary "${build_dir}/test.elf" "${build_dir}/tcm.bin"
  echo "Built binary: $(wc -c < "${build_dir}/tcm.bin") bytes"
}

# ─── Helper: build filelist for a given RTL tree ───
build_core_filelist() {
  local rtl_root="$1"
  local tb_dir="$2"
  local out_list="$3"
  local sanitized_tb="$4"

  # Sanitize testbench for xrun ($fopenr -> $fopen, fix include paths)
  sed -e 's/\$fopenr("\.\/build\/tcm\.bin")/\$fopen(".\/build\/tcm.bin", "rb")/g' \
      -e 's|`include "../../src/core/biriscv_defs.v"|`include "biriscv_defs.v"|g' \
    "${tb_dir}/tb_parallel_matmul.v" > "${sanitized_tb}"

  echo "+incdir+${rtl_root}/src/core" > "${out_list}"
  echo "+incdir+${rtl_root}/src/tcm" >> "${out_list}"
  find "${rtl_root}/src/core" -maxdepth 1 -type f -name '*.v' | sort >> "${out_list}"
  # TCM memory  
  echo "${rtl_root}/src/tcm/tcm_mem.v" >> "${out_list}"
  echo "${rtl_root}/src/tcm/tcm_mem_ram.v" >> "${out_list}"
  echo "${rtl_root}/src/tcm/tcm_mem_pmem.v" >> "${out_list}"
  # Testbench (sanitized)
  echo "${sanitized_tb}" >> "${out_list}"
}

# ─── 1. 2×Standard core (2×MUL) ───
echo "=== Generating VCD for 2×STANDARD core (2×MUL) ==="
TB_2STD="${BIRISCV_2STANDARD}/tb/tb_parallel_matmul"
STD_LIST="${SCRIPT_DIR}/filelists/core_2standard_tb.f"
STD_TB_SANITIZED="${WORK_DIR}/tb_2standard_sanitized.v"
build_core_filelist "${BIRISCV_2STANDARD}" "${TB_2STD}" "${STD_LIST}" "${STD_TB_SANITIZED}"

STD_RUN_DIR="${WORK_DIR}/tb_2standard_run"
mkdir -p "${STD_RUN_DIR}/build"

# Build binary
build_binary "${TB_2STD}/test_parallel_matmul.s" "${STD_RUN_DIR}/build" "${TB_2STD}/link.ld"

(
  cd "${STD_RUN_DIR}"
  rm -f waveform.vcd
  run_xrun "${XRUN_OPTS[@]}" +define+TRACE=1 -f "${STD_LIST}" -top tb_parallel_matmul \
    -input "@run; exit" -l "${LOG_DIR}/xrun_core_2standard.log"
  cp -f waveform.vcd "${OUT_DIR}/core_2standard.vcd"
)
echo "2×Standard VCD: ${OUT_DIR}/core_2standard.vcd"

# ─── 2. Hybrid core (1×MUL + 1×MULE) ───
echo "=== Generating VCD for HYBRID core (1×MUL + 1×MULE) ==="
TB_HYB="${BIRISCV_HYBRID}/tb/tb_parallel_matmul"
HYB_LIST="${SCRIPT_DIR}/filelists/core_hybrid_tb.f"
HYB_TB_SANITIZED="${WORK_DIR}/tb_hybrid_sanitized.v"
build_core_filelist "${BIRISCV_HYBRID}" "${TB_HYB}" "${HYB_LIST}" "${HYB_TB_SANITIZED}"

HYB_RUN_DIR="${WORK_DIR}/tb_hybrid_run"
mkdir -p "${HYB_RUN_DIR}/build"

# Build binary (same assembly, same binary)
build_binary "${TB_HYB}/test_parallel_matmul.s" "${HYB_RUN_DIR}/build" "${TB_HYB}/link.ld"

(
  cd "${HYB_RUN_DIR}"
  rm -f waveform.vcd
  run_xrun "${XRUN_OPTS[@]}" +define+TRACE=1 -f "${HYB_LIST}" -top tb_parallel_matmul \
    -input "@run; exit" -l "${LOG_DIR}/xrun_core_hybrid.log"
  cp -f waveform.vcd "${OUT_DIR}/core_hybrid.vcd"
)
echo "Hybrid VCD: ${OUT_DIR}/core_hybrid.vcd"

echo ""
echo "VCD generation complete: ${OUT_DIR}"
ls -lh "${OUT_DIR}/"

#!/usr/bin/env python3

from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
FLOW_ROOT = SCRIPT_DIR.parent.parent
XRUN_CANDIDATES = [
    Path("/eda/cadence/XCELIUM2509/tools.lnx86/inca/bin/64bit/xrun"),
    Path("/eda/cadence/XCELIUM2509/tools.lnx86/inca/bin/xrun"),
]
RISCV_CANDIDATES = {
    "gcc": [Path("/eda/xilinx/2025.2/gnu/riscv/lin/bin/riscv64-unknown-elf-gcc")],
    "objcopy": [Path("/eda/xilinx/2025.2/gnu/riscv/lin/bin/riscv64-unknown-elf-objcopy")],
    "objdump": [Path("/eda/xilinx/2025.2/gnu/riscv/lin/bin/riscv64-unknown-elf-objdump")],
}
METRIC_RE = re.compile(r"^([A-Za-z0-9_]+)\s*=\s*(-?\d+)\s*$")
TEXT_BASE = 0x80000000
SYMBOL_RE = re.compile(r"^([0-9a-fA-F]+)\s+<([^>]+)>:$")
INSN_RE = re.compile(r"^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]{8})\s+([A-Za-z0-9_.]+)(?:\s+(.*?))?(?:\s+#.*)?$")
R_TYPE_DYNAMIC_FIELDS_MASK = (0x1F << 20) | (0x1F << 15) | (0x1F << 7)

HOT_BENCHMARK_SYMBOLS = {
    "complex_mul_vec": ("kernel_complex_mul_vec",),
    "complex_bank": ("kernel_complex_bank",),
    "estrin_2level": ("kernel_estrin_2level",),
    "estrin_poly": ("kernel_estrin_poly",),
    "extended_estrin": ("kernel_extended_estrin",),
    "filter_bank_4out": ("kernel_filter_bank_4out",),
    "grouped_correlation_bank": ("kernel_grouped_correlation_bank",),
    "multi_accumulator": ("kernel_multi_accumulator",),
    "outer_product": ("kernel_outer_product",),
    "rdr_like_corr": ("kernel_rdr_like_corr",),
    "reduction_tree_mul": ("kernel_reduction_tree_mul",),
    "sliding_correlation": ("kernel_sliding_correlation",),
    "fir_unrolled": ("kernel_fir_unrolled",),
    "fft_butterfly": ("kernel_fft_butterfly",),
    "matmul": ("kernel_matmul",),
    "matmul_tiled": ("kernel_matmul_tiled",),
    "fir_direct": ("kernel_fir_direct",),
    "unrolled_dot8": ("kernel_unrolled_dot8",),
    "unrolled_dot16": ("kernel_unrolled_dot16",),
    "unrolled_dot32": ("kernel_unrolled_dot32",),
    "unrolled_dot64": ("kernel_unrolled_dot64",),
}

ABI_TO_X = {
    "zero": "x0",
    "ra": "x1",
    "sp": "x2",
    "gp": "x3",
    "tp": "x4",
    "t0": "x5",
    "t1": "x6",
    "t2": "x7",
    "s0": "x8",
    "fp": "x8",
    "s1": "x9",
    "a0": "x10",
    "a1": "x11",
    "a2": "x12",
    "a3": "x13",
    "a4": "x14",
    "a5": "x15",
    "a6": "x16",
    "a7": "x17",
    "s2": "x18",
    "s3": "x19",
    "s4": "x20",
    "s5": "x21",
    "s6": "x22",
    "s7": "x23",
    "s8": "x24",
    "s9": "x25",
    "s10": "x26",
    "s11": "x27",
    "t3": "x28",
    "t4": "x29",
    "t5": "x30",
    "t6": "x31",
}
REG_TOK = re.compile(
    r"\b(x(?:[12]?\d|3[01])|zero|ra|sp|gp|tp|t[0-6]|s(?:1[01]|[0-9])|fp|a[0-7])\b"
)
COMPRESSED_RD_READ = frozenset({"c.add", "c.addw", "c.sub", "c.subw", "c.and", "c.or", "c.xor"})


@dataclass(frozen=True)
class InsnRecord:
    address: int
    opcode: int
    mnemonic: str
    operands: str
    symbol: str

    @property
    def text(self) -> str:
        return f"{self.mnemonic} {self.operands}".strip()


@dataclass(frozen=True)
class VariantSpec:
    name: str
    patch_mode: str
    target_name: str | None = None
    target_opcode: int | None = None
    allowed_configs: frozenset[str] = frozenset({"all", "both", "2standard", "hybrid", "singlemul"})


VARIANT_SPECS = {
    "baseline": VariantSpec(
        name="baseline",
        patch_mode="none",
    ),
    "all-mule": VariantSpec(
        name="all-mule",
        patch_mode="all",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"all", "both", "2standard", "hybrid"}),
    ),
    "latency-hidden-mule": VariantSpec(
        name="latency-hidden-mule",
        patch_mode="latency-hidden",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"all", "both", "2standard", "hybrid"}),
    ),
    "selective-latency-hidden-mule": VariantSpec(
        name="selective-latency-hidden-mule",
        patch_mode="selective-latency-hidden",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"all", "both", "2standard", "hybrid"}),
    ),
    "exact-free-mule": VariantSpec(
        name="exact-free-mule",
        patch_mode="exact-free",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "exact-free-relaxed-mule": VariantSpec(
        name="exact-free-relaxed-mule",
        patch_mode="exact-free-relaxed",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "near-free-relaxed-mule": VariantSpec(
        name="near-free-relaxed-mule",
        patch_mode="near-free-relaxed",
        target_name="mule",
        target_opcode=0x0200000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "all-mula": VariantSpec(
        name="all-mula",
        patch_mode="all",
        target_name="mula",
        target_opcode=0x0C00000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "all-mulx": VariantSpec(
        name="all-mulx",
        patch_mode="all",
        target_name="mulx",
        target_opcode=0x0A00000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "all-mulb": VariantSpec(
        name="all-mulb",
        patch_mode="all",
        target_name="mulb",
        target_opcode=0x0E00000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
    "all-mulr": VariantSpec(
        name="all-mulr",
        patch_mode="all",
        target_name="mulr",
        target_opcode=0x0600000B,
        allowed_configs=frozenset({"hybrid"}),
    ),
}


class CommandError(RuntimeError):
    pass


def resolve_executable(name: str, candidates: list[Path]) -> str:
    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)

    resolved = shutil.which(name)
    if resolved:
        return resolved

    raise CommandError(f"required executable not found: {name}")


def run_command(args: list[str], cwd: Path, env: dict[str, str] | None = None, live: bool = False) -> str:
    if not live:
        result = subprocess.run(
            args,
            cwd=str(cwd),
            text=True,
            capture_output=True,
            env=env,
        )
        if result.returncode != 0:
            details = result.stdout
            if result.stderr:
                details = f"{details}\n{result.stderr}".strip()
            raise CommandError(
                f"command failed ({result.returncode}): {' '.join(args)}\n{details}".strip()
            )
        return result.stdout

    process = subprocess.Popen(
        args,
        cwd=str(cwd),
        text=True,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )
    assert process.stdout is not None

    output_chunks: list[str] = []
    for line in process.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        output_chunks.append(line)

    returncode = process.wait()
    output = "".join(output_chunks)
    if returncode != 0:
        raise CommandError(
            f"command failed ({returncode}): {' '.join(args)}\n{output}".strip()
        )
    return output


def stage_benchmark(source_path: Path, staged_path: Path, n_value: int | None, k_value: int | None) -> None:
    text = source_path.read_text(encoding="utf-8")

    def replace_define(body: str, macro: str, value: int | None) -> str:
        if value is None:
            return body
        pattern = re.compile(rf"(^\s*#\s*define\s+{macro}\s+)(\d+)(.*$)", re.MULTILINE)
        replaced, count = pattern.subn(rf"\g<1>{value}\g<3>", body, count=1)
        if count == 0:
            raise CommandError(f"macro {macro} not found in {source_path}")
        return replaced

    text = replace_define(text, "N", n_value)
    text = replace_define(text, "K", k_value)
    staged_path.parent.mkdir(parents=True, exist_ok=True)
    staged_path.write_text(text, encoding="utf-8")


def norm_register(register_name: str) -> str:
    return register_name if register_name.startswith("x") else ABI_TO_X.get(register_name, register_name)


def classify_op(mnemonic: str) -> str:
    if mnemonic in {"lw", "lh", "lb", "lbu", "lhu", "ld", "lwu", "flw", "fld", "c.lw", "c.ld", "c.lwsp", "c.ldsp"}:
        return "load"
    if mnemonic in {"sw", "sh", "sb", "sd", "fsw", "fsd", "c.sw", "c.sd", "c.swsp", "c.sdsp"}:
        return "store"
    if mnemonic in {"mul", "mulh", "mulhu", "mulhsu", "mulw"}:
        return "mul"
    if mnemonic in {"add", "addw", "addi", "addiw", "c.add", "c.addw", "c.addi", "c.addiw", "sub", "subw", "c.sub", "c.subw"}:
        return "add"
    if mnemonic in {"sll", "slli", "slliw", "srl", "srli", "srliw", "sra", "srai", "sraiw", "c.slli", "c.srli", "c.srai"}:
        return "shift"
    if mnemonic.startswith("b") or mnemonic in {"beq", "bne", "blt", "bge", "bltu", "bgeu", "c.beqz", "c.bnez", "jal", "jalr", "c.j", "c.jal", "c.jalr"}:
        return "branch"
    return "other"


def guess_rd_reads(instruction_text: str) -> tuple[str | None, list[str], str, str]:
    tokens = instruction_text.replace(",", " ").replace("(", " ").replace(")", " ").split()
    if not tokens:
        return None, [], "?", "other"

    mnemonic = tokens[0]
    registers = [norm_register(match) for match in REG_TOK.findall(instruction_text)]
    cls = classify_op(mnemonic)

    if cls in {"store", "branch"}:
        return None, registers, mnemonic, cls
    if mnemonic in {"jal", "c.jal"}:
        return (registers[0] if registers else None), [], mnemonic, "branch"
    if mnemonic in {"jalr", "c.jalr"}:
        rd = registers[0] if registers else None
        reads = registers[1:2] if len(registers) >= 2 else []
        return rd, reads, mnemonic, "branch"

    rd = registers[0] if registers else None
    reads = registers[1:] if len(registers) > 1 else []
    if mnemonic in COMPRESSED_RD_READ and rd and rd not in reads:
        reads = [rd] + reads
    return rd, reads, mnemonic, cls


def sanitize_testbench(
    tb_src: Path,
    tb_dst: Path,
    pass_pc: int,
    fail_pc: int,
    timeout_cycles: int,
    dump_vcd: bool,
) -> None:
    text = tb_src.read_text(encoding="utf-8")
    text = text.replace('$fopenr("./build/tcm.bin")', '$fopen("./build/tcm.bin", "rb")')
    text = text.replace("if (`TRACE) begin", f"if ({1 if dump_vcd else 0}) begin", 1)
    text = re.sub(
        r"localparam PASS_PC = 32'h[0-9a-fA-F]+;",
        f"localparam PASS_PC = 32'h{pass_pc:08x};",
        text,
        count=1,
    )
    text = re.sub(
        r"localparam FAIL_PC = 32'h[0-9a-fA-F]+;",
        f"localparam FAIL_PC = 32'h{fail_pc:08x};",
        text,
        count=1,
    )
    text = re.sub(
        r"localparam TIMEOUT_CYCLES = 64'd\d+;",
        f"localparam TIMEOUT_CYCLES = 64'd{timeout_cycles};",
        text,
        count=1,
    )
    if "wire [31:0] pipe0_retire_pc_w = u_dut.u_issue.pipe0_pc_wb_w;" not in text:
        text = text.replace(
            "wire [31:0] pipe1_retire_opcode_w = u_dut.u_issue.pipe1_opc_wb_w;\n",
            "wire [31:0] pipe1_retire_opcode_w = u_dut.u_issue.pipe1_opc_wb_w;\nwire [31:0] pipe0_retire_pc_w = u_dut.u_issue.pipe0_pc_wb_w;\nwire [31:0] pipe1_retire_pc_w = u_dut.u_issue.pipe1_pc_wb_w;\n",
            1,
        )
    text = text.replace(
        "if (!pass_reported && mem_i_pc_w == PASS_PC) begin",
        "if (!pass_reported && ((pipe0_retire_w && pipe0_retire_pc_w == PASS_PC) || (pipe1_retire_w && pipe1_retire_pc_w == PASS_PC))) begin",
        1,
    )
    text = text.replace(
        "end else if (!fail_reported && mem_i_pc_w == FAIL_PC) begin",
        "end else if (!fail_reported && ((pipe0_retire_w && pipe0_retire_pc_w == FAIL_PC) || (pipe1_retire_w && pipe1_retire_pc_w == FAIL_PC))) begin",
        1,
    )
    tb_dst.parent.mkdir(parents=True, exist_ok=True)
    tb_dst.write_text(text, encoding="utf-8")


def build_binary(
    staged_benchmark: Path,
    build_dir: Path,
    tb_assets_dir: Path,
) -> tuple[Path, Path]:
    gcc = resolve_executable("riscv64-unknown-elf-gcc", RISCV_CANDIDATES["gcc"])
    objcopy = resolve_executable("riscv64-unknown-elf-objcopy", RISCV_CANDIDATES["objcopy"])
    start_src = tb_assets_dir / "start_bench.S"
    stub_src = tb_assets_dir / "bench_stdio_stub.c"
    link_ld = tb_assets_dir / "link.ld"
    staged_link_ld = build_dir / "link.ld"
    build_dir.mkdir(parents=True, exist_ok=True)

    start_obj = build_dir / "start.o"
    bench_obj = build_dir / "bench_main.o"
    support_obj = build_dir / "bench_support.o"
    elf_path = build_dir / "benchmark.elf"
    bin_path = build_dir / "tcm.bin"

    link_text = link_ld.read_text(encoding="utf-8")
    link_text = link_text.replace(".text ALIGN(256) : {", ".text : {")
    link_text = link_text.replace(
        "        *(.comment)\n        *(.riscv.attributes)\n",
        "        *(.comment)\n        *(.riscv.attributes)\n        *(.note*)\n",
    )
    staged_link_ld.write_text(link_text, encoding="utf-8")

    common_cflags = [
        "-march=rv32im",
        "-mabi=ilp32",
        "-O2",
        "-ffreestanding",
        "-fno-builtin",
        "-fno-common",
        "-msmall-data-limit=0",
        f"-I{tb_assets_dir}",
    ]

    run_command([gcc, *common_cflags, "-c", str(start_src), "-o", str(start_obj)], build_dir)
    run_command([gcc, *common_cflags, "-c", str(staged_benchmark), "-o", str(bench_obj)], build_dir)
    run_command([gcc, *common_cflags, "-c", str(stub_src), "-o", str(support_obj)], build_dir)
    run_command(
        [
            gcc,
            "-march=rv32im",
            "-mabi=ilp32",
            "-nostdlib",
            "-nostartfiles",
            f"-Wl,-T{staged_link_ld}",
            "-Wl,--build-id=none",
            "-Wl,--gc-sections",
            "-o",
            str(elf_path),
            str(start_obj),
            str(bench_obj),
            str(support_obj),
            "-lgcc",
        ],
        build_dir,
    )
    run_command([objcopy, "-O", "binary", str(elf_path), str(bin_path)], build_dir)
    return elf_path, bin_path


def disassemble_elf(elf_path: Path) -> str:
    objdump = resolve_executable("riscv64-unknown-elf-objdump", RISCV_CANDIDATES["objdump"])
    return run_command([objdump, "-d", str(elf_path)], elf_path.parent)


def parse_disassembly(disassembly: str) -> list[InsnRecord]:
    records: list[InsnRecord] = []
    current_symbol = ""
    for line in disassembly.splitlines():
        stripped = line.strip()
        symbol_match = SYMBOL_RE.match(stripped)
        if symbol_match:
            current_symbol = symbol_match.group(2)
            continue

        insn_match = INSN_RE.match(line)
        if not insn_match:
            continue

        records.append(
            InsnRecord(
                address=int(insn_match.group(1), 16),
                opcode=int(insn_match.group(2), 16),
                mnemonic=insn_match.group(3),
                operands=(insn_match.group(4) or "").strip(),
                symbol=current_symbol,
            )
        )
    return records


def patch_r_type_opcode(source_opcode: int, target_opcode: int) -> int:
    return (source_opcode & R_TYPE_DYNAMIC_FIELDS_MASK) | (target_opcode & ~R_TYPE_DYNAMIC_FIELDS_MASK)


def patch_mul_to_variant(binary_path: Path, records: list[InsnRecord], variant_spec: VariantSpec) -> int:
    if variant_spec.target_opcode is None or variant_spec.target_name is None:
        raise CommandError(f"variant {variant_spec.name} does not define a patch target")

    image = bytearray(binary_path.read_bytes())
    patch_count = 0

    for record in records:
        if record.mnemonic != "mul":
            continue
        offset = record.address - TEXT_BASE
        if offset < 0 or (offset + 4) > len(image):
            raise CommandError(
                f"mul instruction address 0x{record.address:08x} is outside the flat binary range"
            )
        image[offset:offset + 4] = patch_r_type_opcode(record.opcode, variant_spec.target_opcode).to_bytes(
            4,
            byteorder="little",
        )
        patch_count += 1

    binary_path.write_bytes(image)
    return patch_count


def patch_selected_mul_to_variant(
    binary_path: Path,
    records: list[InsnRecord],
    selected_addresses: set[int],
    variant_spec: VariantSpec,
) -> int:
    if variant_spec.target_opcode is None or variant_spec.target_name is None:
        raise CommandError(f"variant {variant_spec.name} does not define a patch target")

    image = bytearray(binary_path.read_bytes())
    patch_count = 0

    for record in records:
        if record.address not in selected_addresses:
            continue
        if record.mnemonic != "mul":
            raise CommandError(
                f"selected latency-hidden instruction at 0x{record.address:08x} is not a plain mul"
            )
        offset = record.address - TEXT_BASE
        if offset < 0 or (offset + 4) > len(image):
            raise CommandError(
                f"selected mul instruction address 0x{record.address:08x} is outside the flat binary range"
            )
        image[offset:offset + 4] = patch_r_type_opcode(record.opcode, variant_spec.target_opcode).to_bytes(
            4,
            byteorder="little",
        )
        patch_count += 1

    binary_path.write_bytes(image)
    return patch_count


def hot_symbols_for_benchmark(benchmark_stem: str) -> tuple[str, ...]:
    return HOT_BENCHMARK_SYMBOLS.get(benchmark_stem, ("main",))


def static_distance_to_first_consumer(records: list[InsnRecord], producer_index: int, producer_rd: str) -> int | None:
    for consumer_index in range(producer_index + 1, len(records)):
        consumer_rd, consumer_reads, _, _ = guess_rd_reads(records[consumer_index].text)
        if producer_rd in consumer_reads:
            return consumer_index - producer_index
        if consumer_rd == producer_rd:
            return None
    return None


def select_latency_hidden_mul_addresses(records: list[InsnRecord], benchmark_stem: str, distance_threshold: int) -> set[int]:
    hot_symbols = hot_symbols_for_benchmark(benchmark_stem)
    scoped_records = [record for record in records if record.symbol in hot_symbols]
    if not scoped_records:
        raise CommandError(
            f"no disassembly records found for latency-hidden symbols {hot_symbols} in benchmark {benchmark_stem}"
        )

    selected_addresses: set[int] = set()
    for index, record in enumerate(scoped_records):
        if record.mnemonic != "mul":
            continue
        producer_rd, _, _, _ = guess_rd_reads(record.text)
        if producer_rd is None:
            continue
        distance = static_distance_to_first_consumer(scoped_records, index, producer_rd)
        if distance is not None and distance >= distance_threshold:
            selected_addresses.add(record.address)

    if not selected_addresses:
        raise CommandError(
            f"no latency-hidden plain mul instructions met distance >= {distance_threshold} in symbols {hot_symbols} for benchmark {benchmark_stem}"
        )
    return selected_addresses


def load_metrics_json(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def branch_target_address(record: InsnRecord) -> int | None:
    if classify_op(record.mnemonic) != "branch":
        return None
    match = re.search(r"\b([0-9a-fA-F]{8})\b", record.operands)
    return None if not match else int(match.group(1), 16)


def detect_loop_ranges(scoped_records: list[InsnRecord]) -> list[tuple[int, int]]:
    addr_to_index = {record.address: index for index, record in enumerate(scoped_records)}
    loops: list[tuple[int, int]] = []
    for index, record in enumerate(scoped_records):
        target = branch_target_address(record)
        if target is None or target >= record.address or target not in addr_to_index:
            continue
        start_index = addr_to_index[target]
        if scoped_records[start_index].symbol != record.symbol:
            continue
        loops.append((start_index, index))
    loops.sort(key=lambda item: (item[1] - item[0], item[0], item[1]))
    return loops


def enclosing_loop_key(index: int, scoped_records: list[InsnRecord], loops: list[tuple[int, int]]) -> tuple[str, str, int, int]:
    for start_index, end_index in loops:
        if start_index <= index <= end_index:
            return (
                "loop",
                scoped_records[index].symbol,
                scoped_records[start_index].address,
                scoped_records[end_index].address,
            )
    return ("symbol", scoped_records[index].symbol, 0, 0)


def read_baseline_metrics(out_root: Path, benchmark_name: str, config_name: str) -> dict[str, object]:
    baseline_metrics_path = out_root.parent / benchmark_name / "metrics" / f"{config_name}.json"
    if not baseline_metrics_path.is_file():
        raise CommandError(
            f"baseline metrics required for selective steering were not found: {baseline_metrics_path}"
        )
    return load_metrics_json(baseline_metrics_path)


def baseline_plain_mul_retire_count(baseline_metrics: dict[str, object]) -> int:
    metrics = baseline_metrics.get("metrics", {})
    if not isinstance(metrics, dict):
        return 0
    if "retired_plain_mul" in metrics:
        return int(metrics["retired_plain_mul"])
    if "retired_integer_multiply_total" in metrics:
        return int(metrics["retired_integer_multiply_total"])
    return 0


def per_group_patch_fraction(amplification: float) -> float:
    if amplification > 4096.0:
        return 0.25
    if amplification > 1024.0:
        return 1.0 / 3.0
    return 0.5


def budget_for_group(static_mul_count: int, amplification: float) -> int:
    if static_mul_count <= 0:
        return 0
    if static_mul_count == 1 and amplification > 1024.0:
        return 0

    budget = int(static_mul_count * per_group_patch_fraction(amplification) + 0.5)
    if static_mul_count > 1:
        budget = max(1, budget)
        if amplification > 256.0:
            budget = min(budget, static_mul_count - 1)
    else:
        budget = min(1, budget)
    return min(static_mul_count, budget)


def select_selective_latency_hidden_mul_addresses(
    records: list[InsnRecord],
    benchmark_stem: str,
    distance_threshold: int,
    baseline_metrics: dict[str, object],
) -> set[int]:
    hot_symbols = hot_symbols_for_benchmark(benchmark_stem)
    scoped_records = [record for record in records if record.symbol in hot_symbols]
    if not scoped_records:
        raise CommandError(
            f"no disassembly records found for selective steering symbols {hot_symbols} in benchmark {benchmark_stem}"
        )

    loops = detect_loop_ranges(scoped_records)
    baseline_retired_plain_mul = baseline_plain_mul_retire_count(baseline_metrics)

    group_all_mul_ordinals: dict[tuple[str, str, int, int], list[int]] = {}
    candidate_rows: list[dict[str, int | tuple[str, str, int, int]]] = []
    for index, record in enumerate(scoped_records):
        if record.mnemonic != "mul":
            continue
        group_key = enclosing_loop_key(index, scoped_records, loops)
        ordinal_list = group_all_mul_ordinals.setdefault(group_key, [])
        ordinal_list.append(index)

        producer_rd, _, _, _ = guess_rd_reads(record.text)
        if producer_rd is None:
            continue
        distance = static_distance_to_first_consumer(scoped_records, index, producer_rd)
        if distance is None or distance < distance_threshold:
            continue
        candidate_rows.append(
            {
                "index": index,
                "address": record.address,
                "distance": distance,
                "group_key": group_key,
            }
        )

    if not candidate_rows:
        return set()

    candidate_rows_by_group: dict[tuple[str, str, int, int], list[dict[str, int | tuple[str, str, int, int]]]] = {}
    for row in candidate_rows:
        group_key = row["group_key"]
        assert isinstance(group_key, tuple)
        candidate_rows_by_group.setdefault(group_key, []).append(row)

    selected_addresses: set[int] = set()
    for group_key, rows in candidate_rows_by_group.items():
        all_ordinals = group_all_mul_ordinals[group_key]
        static_mul_count = len(all_ordinals)
        amplification = (
            0.0 if static_mul_count == 0 else float(baseline_retired_plain_mul) / float(static_mul_count)
        )
        budget = budget_for_group(static_mul_count, amplification)
        if budget <= 0:
            continue

        ordinal_position = {ordinal: position for position, ordinal in enumerate(all_ordinals)}
        ordered_rows = sorted(
            rows,
            key=lambda row: (-int(row["distance"]), int(row["index"]), int(row["address"])),
        )

        chosen_ordinals: list[int] = []
        chosen_addresses: list[int] = []
        deferred_rows: list[dict[str, int | tuple[str, str, int, int]]] = []
        for row in ordered_rows:
            ordinal = ordinal_position[int(row["index"])]
            if all(abs(ordinal - prior) > 1 for prior in chosen_ordinals):
                chosen_ordinals.append(ordinal)
                chosen_addresses.append(int(row["address"]))
                if len(chosen_addresses) >= budget:
                    break
            else:
                deferred_rows.append(row)

        if len(chosen_addresses) < budget:
            for row in deferred_rows:
                chosen_addresses.append(int(row["address"]))
                if len(chosen_addresses) >= budget:
                    break

        selected_addresses.update(chosen_addresses)

    return selected_addresses


def select_exact_free_candidate_addresses(
    records: list[InsnRecord],
    benchmark_stem: str,
    distance_threshold: int,
    baseline_metrics: dict[str, object],
    relaxed: bool = False,
) -> list[int]:
    hot_symbols = hot_symbols_for_benchmark(benchmark_stem)
    scoped_records = [record for record in records if record.symbol in hot_symbols]
    if not scoped_records:
        raise CommandError(
            f"no disassembly records found for exact-free steering symbols {hot_symbols} in benchmark {benchmark_stem}"
        )

    loops = detect_loop_ranges(scoped_records)
    baseline_retired_plain_mul = baseline_plain_mul_retire_count(baseline_metrics)

    group_all_mul_ordinals: dict[tuple[str, str, int, int], list[int]] = {}
    candidate_rows: list[dict[str, int | float | tuple[str, str, int, int]]] = []
    for index, record in enumerate(scoped_records):
        if record.mnemonic != "mul":
            continue
        group_key = enclosing_loop_key(index, scoped_records, loops)
        group_all_mul_ordinals.setdefault(group_key, []).append(index)

    for index, record in enumerate(scoped_records):
        if record.mnemonic != "mul":
            continue
        producer_rd, _, _, _ = guess_rd_reads(record.text)
        if producer_rd is None:
            continue
        distance = static_distance_to_first_consumer(scoped_records, index, producer_rd)
        if not relaxed and (distance is None or distance < distance_threshold):
            continue
        if relaxed and distance is not None and distance < distance_threshold:
            continue

        group_key = enclosing_loop_key(index, scoped_records, loops)
        static_mul_count = len(group_all_mul_ordinals[group_key])
        amplification = (
            0.0 if static_mul_count == 0 else float(baseline_retired_plain_mul) / float(static_mul_count)
        )
        if not relaxed and static_mul_count == 1 and amplification > 1024.0:
            continue

        ordinal = group_all_mul_ordinals[group_key].index(index)
        candidate_rows.append(
            {
                "index": index,
                "address": record.address,
                "distance": -1 if distance is None else distance,
                "group_key": group_key,
                "static_mul_count": static_mul_count,
                "amplification": amplification,
                "ordinal": ordinal,
            }
        )

    candidate_rows.sort(
        key=lambda row: (
            -(int(row["distance"]) if int(row["distance"]) >= 0 else 9999),
            float(row["amplification"]),
            int(row["static_mul_count"]),
            int(row["ordinal"]),
            int(row["address"]),
        )
    )
    return [int(row["address"]) for row in candidate_rows]


def resolve_loop_addresses(elf_path: Path) -> tuple[int, int]:
    disassembly = disassemble_elf(elf_path)

    def find_symbol(symbol: str) -> int:
        match = re.search(rf"^([0-9a-fA-F]+)\s+<{symbol}>:$", disassembly, re.MULTILINE)
        if not match:
            raise CommandError(f"symbol {symbol} not found in {elf_path}")
        return int(match.group(1), 16)

    return find_symbol("pass_loop"), find_symbol("fail_loop")


def core_sources(core_root: Path, tb_sanitized: Path, tb_mul_dir: Path) -> list[str]:
    core_dir = core_root / "src" / "core"
    sources = [str(path) for path in sorted(core_dir.glob("*.v"))]
    sources.extend(
        [
            str(tb_sanitized),
            str(tb_mul_dir / "tcm_mem.v"),
            str(tb_mul_dir / "tcm_mem_ram.v"),
        ]
    )
    return sources


def parse_metrics(output_text: str) -> dict[str, int]:
    metrics: dict[str, int] = {}
    for line in output_text.splitlines():
        match = METRIC_RE.match(line.strip())
        if match:
            metrics[match.group(1)] = int(match.group(2))
    return metrics


def clone_baseline_artifacts(
    baseline_metrics: dict[str, object],
    benchmark_src: Path,
    config_name: str,
    variant: str,
    variant_spec: VariantSpec,
    log_path: Path,
    vcd_path: Path,
    dump_vcd: bool,
    metrics_dir: Path,
) -> dict[str, object]:
    baseline_log_path = Path(str(baseline_metrics.get("log_path", "")))
    baseline_vcd_path = Path(str(baseline_metrics.get("vcd_path", ""))) if baseline_metrics.get("vcd_path") else None

    def link_or_copy(src: Path, dst: Path) -> None:
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists() or dst.is_symlink():
            dst.unlink()
        try:
            os.link(src, dst)
        except OSError:
            shutil.copyfile(src, dst)

    if baseline_log_path.is_file():
        link_or_copy(baseline_log_path, log_path)
    else:
        log_path.parent.mkdir(parents=True, exist_ok=True)
        log_path.write_text(
            "selective steering selected zero patch sites; reused baseline execution artifacts\n",
            encoding="utf-8",
        )

    if dump_vcd:
        if baseline_vcd_path is None or not baseline_vcd_path.is_file():
            raise CommandError(
                f"baseline VCD required for zero-patch selective replay was not found: {baseline_vcd_path}"
            )
        link_or_copy(baseline_vcd_path, vcd_path)

    baseline_metrics_map = baseline_metrics.get("metrics", {})
    if not isinstance(baseline_metrics_map, dict):
        raise CommandError("baseline metrics payload is malformed for zero-patch selective replay")

    result = {
        "config": config_name,
        "variant": variant,
        "status": str(baseline_metrics.get("status", "pass")),
        "benchmark": benchmark_src.name,
        "patched_plain_mul_count": 0,
        "selected_plain_mul_addresses": [],
        "patched_target": variant_spec.target_name,
        "patched_target_opcode": None if variant_spec.target_opcode is None else f"0x{variant_spec.target_opcode:08x}",
        "metrics": baseline_metrics_map,
        "log_path": str(log_path),
        "vcd_path": None if not dump_vcd else str(vcd_path),
        "artifact_reuse": "baseline",
    }
    (metrics_dir / f"{config_name}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                "config": config_name,
                "variant": variant,
                "artifact_reuse": "baseline",
                "reason": "no safe selective mule candidates",
            },
            indent=2,
        )
    )
    return result


def run_xcelium_simulation(
    xrun: str,
    config_name: str,
    core_root: Path,
    tb_assets_dir: Path,
    tb_sanitized: Path,
    run_dir: Path,
    xmlib_dir: Path,
    log_path: Path,
    trace_retire: bool,
    dump_vcd: bool,
    env: dict[str, str],
) -> str:
    tb_mul_dir = tb_assets_dir.parent / "tb_mul"
    print(f"[{config_name}] Streaming Xcelium output; full log: {log_path}")
    return run_command(
        [
            xrun,
            "-64bit",
            "-sv",
            "-licqueue",
            "-timescale",
            "1ns/1ps",
            "+access+r",
            f"+define+TRACE={1 if trace_retire else 0}",
            f"+define+TRACE_VCD={1 if dump_vcd else 0}",
            "+define+verilog_sim",
            f"+incdir+{core_root / 'src' / 'core'}",
            f"+incdir+{tb_assets_dir}",
            f"+incdir+{tb_mul_dir}",
            "-xmlibdirname",
            str(xmlib_dir),
            *core_sources(core_root, tb_sanitized, tb_mul_dir),
            "-top",
            "tb_matmul_absorbtion",
            "-input",
            "@run; exit",
            "-l",
            str(log_path),
        ],
        run_dir,
        env=env,
        live=True,
    )


def run_config(
    config_name: str,
    core_root: Path,
    tb_assets_dir: Path,
    benchmark_src: Path,
    benchmark_name: str,
    out_root: Path,
    staged_benchmark: Path,
    timeout_cycles: int,
    variant: str,
    distance_threshold: int,
    trace_retire: bool,
    dump_vcd: bool,
    oracle_cycle_tolerance_pct: float,
) -> dict[str, object]:
    xrun = resolve_executable("xrun", XRUN_CANDIDATES)
    variant_spec = VARIANT_SPECS[variant]
    tb_sanitized = out_root / "work" / config_name / "tb_matmul_absorbtion_sanitized.v"

    run_dir = out_root / "work" / config_name
    build_dir = run_dir / "build"
    log_dir = out_root / "logs"
    vcd_dir = out_root / "vcd"
    metrics_dir = out_root / "metrics"
    for path in [run_dir, build_dir, log_dir, vcd_dir, metrics_dir]:
        path.mkdir(parents=True, exist_ok=True)

    elf_path, tcm_bin = build_binary(staged_benchmark, build_dir, tb_assets_dir)
    original_tcm_image = tcm_bin.read_bytes()
    records = parse_disassembly(disassemble_elf(elf_path))
    patched_plain_mul_count = 0
    selected_addresses: set[int] = set()
    baseline_metrics: dict[str, object] | None = None
    oracle_candidates: list[int] = []
    oracle_rejected: list[dict[str, int]] = []
    if variant_spec.patch_mode == "all":
        patched_plain_mul_count = patch_mul_to_variant(tcm_bin, records, variant_spec)
    elif variant_spec.patch_mode == "latency-hidden":
        selected_addresses = select_latency_hidden_mul_addresses(records, benchmark_src.stem, distance_threshold)
        patched_plain_mul_count = patch_selected_mul_to_variant(tcm_bin, records, selected_addresses, variant_spec)
    elif variant_spec.patch_mode == "selective-latency-hidden":
        baseline_metrics = read_baseline_metrics(out_root, benchmark_name, config_name)
        selected_addresses = select_selective_latency_hidden_mul_addresses(
            records,
            benchmark_src.stem,
            distance_threshold,
            baseline_metrics,
        )
        if selected_addresses:
            patched_plain_mul_count = patch_selected_mul_to_variant(tcm_bin, records, selected_addresses, variant_spec)
    elif variant_spec.patch_mode in {"exact-free", "exact-free-relaxed", "near-free-relaxed"}:
        baseline_metrics = read_baseline_metrics(out_root, benchmark_name, config_name)
        oracle_candidates = select_exact_free_candidate_addresses(
            records,
            benchmark_src.stem,
            distance_threshold,
            baseline_metrics,
            relaxed=(variant_spec.patch_mode in {"exact-free-relaxed", "near-free-relaxed"}),
        )
    pass_pc, fail_pc = resolve_loop_addresses(elf_path)

    log_path = log_dir / f"{config_name}.log"
    vcd_path = vcd_dir / f"{config_name}.vcd"
    xmlib_dir = run_dir / "xcelium.d"
    env = os.environ.copy()
    env.pop("LD_LIBRARY_PATH", None)

    if variant_spec.patch_mode in {"exact-free", "exact-free-relaxed", "near-free-relaxed"}:
        if baseline_metrics is None:
            raise CommandError("baseline metrics unexpectedly missing for exact-free steering")
        baseline_metrics_map = baseline_metrics.get("metrics", {})
        if not isinstance(baseline_metrics_map, dict) or "sim_total_cycles" not in baseline_metrics_map:
            raise CommandError("baseline metrics payload is missing sim_total_cycles for exact-free steering")
        baseline_cycles = int(baseline_metrics_map["sim_total_cycles"])
        max_accepted_cycles = baseline_cycles
        if variant_spec.patch_mode == "near-free-relaxed":
            max_accepted_cycles = baseline_cycles + int((baseline_cycles * oracle_cycle_tolerance_pct) // 100.0)
        sanitize_testbench(
            tb_assets_dir / "tb_matmul_absorbtion.v",
            tb_sanitized,
            pass_pc,
            fail_pc,
            timeout_cycles,
            False,
        )

        accepted_addresses: list[int] = []
        for trial_index, candidate_address in enumerate(oracle_candidates, start=1):
            trial_addresses = set(accepted_addresses + [candidate_address])
            tcm_bin.write_bytes(original_tcm_image)
            patch_selected_mul_to_variant(tcm_bin, records, trial_addresses, variant_spec)
            trial_log = log_dir / f"{config_name}_trial_{trial_index:02d}_{candidate_address:08x}.log"
            output = run_xcelium_simulation(
                xrun,
                config_name,
                core_root,
                tb_assets_dir,
                tb_sanitized,
                run_dir,
                xmlib_dir,
                trial_log,
                trace_retire,
                False,
                env,
            )
            if "*** BENCHMARK PASS ***" not in output:
                raise CommandError(f"exact-free oracle trial failed golden check for 0x{candidate_address:08x}")
            trial_metrics = parse_metrics(output)
            trial_cycles = int(trial_metrics.get("sim_total_cycles", 0))
            if trial_cycles <= max_accepted_cycles:
                accepted_addresses.append(candidate_address)
            else:
                oracle_rejected.append({"address": candidate_address, "trial_cycles": trial_cycles})

        selected_addresses = set(accepted_addresses)
        if selected_addresses:
            tcm_bin.write_bytes(original_tcm_image)
            patched_plain_mul_count = patch_selected_mul_to_variant(tcm_bin, records, selected_addresses, variant_spec)

    if variant_spec.patch_mode == "selective-latency-hidden" and not selected_addresses:
        if baseline_metrics is None:
            raise CommandError("baseline metrics unexpectedly missing for zero-patch selective replay")
        return clone_baseline_artifacts(
            baseline_metrics,
            benchmark_src,
            config_name,
            variant,
            variant_spec,
            log_path,
            vcd_path,
            dump_vcd,
            metrics_dir,
        )

    if variant_spec.patch_mode in {"exact-free", "exact-free-relaxed", "near-free-relaxed"} and not selected_addresses:
        if baseline_metrics is None:
            raise CommandError("baseline metrics unexpectedly missing for zero-patch exact-free replay")
        return clone_baseline_artifacts(
            baseline_metrics,
            benchmark_src,
            config_name,
            variant,
            variant_spec,
            log_path,
            vcd_path,
            False,
            metrics_dir,
        )

    sanitize_testbench(
        tb_assets_dir / "tb_matmul_absorbtion.v",
        tb_sanitized,
        pass_pc,
        fail_pc,
        timeout_cycles,
        dump_vcd,
    )

    output = run_xcelium_simulation(
        xrun,
        config_name,
        core_root,
        tb_assets_dir,
        tb_sanitized,
        run_dir,
        xmlib_dir,
        log_path,
        trace_retire,
        dump_vcd,
        env,
    )

    if dump_vcd:
        waveform = run_dir / "waveform.vcd"
        if not waveform.exists():
            raise CommandError(f"waveform not produced for {config_name}")
        shutil.copyfile(waveform, vcd_path)

    metrics = parse_metrics(output)
    result = {
        "config": config_name,
        "variant": variant,
        "status": "pass" if "*** BENCHMARK PASS ***" in output else "fail",
        "benchmark": benchmark_src.name,
        "patched_plain_mul_count": patched_plain_mul_count,
        "selected_plain_mul_addresses": [f"0x{address:08x}" for address in sorted(selected_addresses)],
        "patched_target": variant_spec.target_name,
        "patched_target_opcode": None if variant_spec.target_opcode is None else f"0x{variant_spec.target_opcode:08x}",
        "metrics": metrics,
        "log_path": str(log_path),
        "vcd_path": None if not dump_vcd else str(vcd_path),
    }
    if variant_spec.patch_mode in {"exact-free", "exact-free-relaxed", "near-free-relaxed"}:
        result["oracle_candidate_count"] = len(oracle_candidates)
        result["oracle_cycle_tolerance_pct"] = oracle_cycle_tolerance_pct if variant_spec.patch_mode == "near-free-relaxed" else 0.0
        result["oracle_rejected"] = [
            {"address": f"0x{row['address']:08x}", "trial_cycles": row["trial_cycles"]}
            for row in oracle_rejected
        ]
    (metrics_dir / f"{config_name}.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate matched Xcelium VCDs for a C benchmark on 2standard, hybrid, and single-MUL biRISC-V cores.")
    parser.add_argument("benchmark", help="Absolute or relative path to benchmark C source")
    parser.add_argument("--benchmark-name", help="Override output benchmark name directory")
    parser.add_argument("--n", type=int, help="Override #define N in the staged benchmark source")
    parser.add_argument("--k", type=int, help="Override #define K in the staged benchmark source")
    parser.add_argument("--timeout-cycles", type=int, default=2000000, help="Timeout stamped into the sanitized benchmark testbench")
    parser.add_argument("--config", choices=["all", "both", "2standard", "hybrid", "singlemul"], default="both")
    parser.add_argument("--trace-retire", action="store_true", help="Enable verbose retire_trace printing in the benchmark testbench output")
    parser.add_argument("--no-vcd", action="store_true", help="Disable waveform dumping for faster cycle-only smoke tests")
    parser.add_argument(
        "--variant",
        choices=sorted(VARIANT_SPECS),
        default="baseline",
        help="Instruction mix to run; baseline leaves plain MUL unchanged, all-* rewrites every plain MUL to the named custom multiplier, latency-hidden-mule rewrites every hot-function plain MUL whose first static consumer is far enough away, and selective-latency-hidden-mule adds throughput guards on top of that distance filter",
    )
    parser.add_argument(
        "--latency-distance-threshold",
        type=int,
        default=2,
        help="Static producer-to-consumer instruction distance required for latency-hidden-mule selection",
    )
    parser.add_argument(
        "--oracle-cycle-tolerance-pct",
        type=float,
        default=0.0,
        help="Cycle overhead tolerance for near-free oracle variants, in percent of baseline cycles",
    )
    parser.add_argument(
        "--output-root",
        default=str(SCRIPT_DIR / "outputs" / "benchmark_runs"),
        help="Base output directory",
    )
    parser.add_argument("--bIRISCV-hybrid", dest="biriscv_hybrid", default=os.environ.get("BIRISCV_HYBRID", "/home/ykaraagac/biriscv"))
    parser.add_argument("--bIRISCV-2standard", dest="biriscv_2standard", default=os.environ.get("BIRISCV_2STANDARD", "/home/ykaraagac/biriscv-2standard"))
    parser.add_argument("--bIRISCV-singlemul", dest="biriscv_singlemul", default=os.environ.get("BIRISCV_SINGLEMUL", "/home/ykaraagac/biriscv-singlemul"))
    args = parser.parse_args()

    benchmark_src = Path(args.benchmark).resolve()
    if not benchmark_src.is_file():
        raise CommandError(f"benchmark source not found: {benchmark_src}")

    biriscv_hybrid = Path(args.biriscv_hybrid).resolve()
    biriscv_2standard = Path(args.biriscv_2standard).resolve()
    biriscv_singlemul = Path(args.biriscv_singlemul).resolve()
    tb_assets_dir = biriscv_hybrid / "tb" / "tb_matmul_absorbtion"
    if not tb_assets_dir.is_dir():
        raise CommandError(f"generic testbench assets not found: {tb_assets_dir}")

    benchmark_name = args.benchmark_name or benchmark_src.stem
    out_name = benchmark_name if args.variant == "baseline" else f"{benchmark_name}_{args.variant.replace('-', '_')}"
    out_root = Path(args.output_root).resolve() / out_name
    staged_dir = out_root / "staged"
    staged_src = staged_dir / benchmark_src.name
    stage_benchmark(benchmark_src, staged_src, args.n, args.k)

    variant_spec = VARIANT_SPECS[args.variant]
    if args.config not in variant_spec.allowed_configs:
        allowed_configs = ", ".join(sorted(variant_spec.allowed_configs))
        raise CommandError(f"variant {args.variant} requires --config to be one of: {allowed_configs}")

    configs: list[tuple[str, Path]] = []
    if args.config in {"all", "both", "2standard"}:
        configs.append(("core_2standard", biriscv_2standard))
    if args.config in {"all", "both", "hybrid"}:
        configs.append(("core_hybrid", biriscv_hybrid))
    if args.variant == "baseline" and args.config in {"all", "singlemul"}:
        configs.append(("core_singlemul", biriscv_singlemul))

    summary = {"benchmark": str(benchmark_src), "variant": args.variant, "results": []}
    for config_name, core_root in configs:
        summary["results"].append(
            run_config(
                config_name,
                core_root,
                tb_assets_dir,
                benchmark_src,
                benchmark_name,
                out_root,
                staged_src,
                args.timeout_cycles,
                args.variant,
                args.latency_distance_threshold,
                args.trace_retire,
                not args.no_vcd,
                args.oracle_cycle_tolerance_pct,
            )
        )

    (out_root / "summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except CommandError as exc:
        print(f"ERROR: {exc}")
        raise SystemExit(2)

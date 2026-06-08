#!/usr/bin/env python3

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUN_ROOT = ROOT / "outputs" / "job6_selective_runs"
POWER_ROOT = ROOT / "outputs" / "job6_selective_power"
BENCHMARKS = [
    "complex_mul_vec",
    "fft_butterfly",
    "fir_direct",
    "fir_unrolled",
    "matmul_tiled",
    "outer_product",
    "complex_bank",
    "estrin_2level",
    "estrin_poly",
    "extended_estrin",
    "filter_bank_4out",
    "grouped_correlation_bank",
    "multi_accumulator",
    "rdr_like_corr",
    "reduction_tree_mul",
    "sliding_correlation",
    "unrolled_dot8",
    "unrolled_dot16",
    "unrolled_dot32",
    "unrolled_dot64",
]


@dataclass
class PowerRecord:
    total_mw: float
    mule_mw: float


def load_metrics(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_cycles(path: Path) -> int:
    data = load_metrics(path)
    metrics = data["metrics"]
    assert isinstance(metrics, dict)
    return int(metrics["sim_total_cycles"])


def read_report_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def extract_total_power(path: Path) -> float:
    text = read_report_text(path)
    match = re.search(r"^Total Power:\s+([0-9.]+)$", text, re.M)
    if not match:
        raise RuntimeError(f"missing Total Power in {path}")
    return float(match.group(1))


def extract_instance_total(path: Path) -> float:
    text = read_report_text(path)
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("*") or stripped.startswith("-"):
            continue
        parts = stripped.split()
        if len(parts) >= 7 and parts[0] == "u_mule":
            return float(parts[6])
    raise RuntimeError(f"missing u_mule instance total in {path}")


def collect_power(bench: str, flavor: str) -> PowerRecord:
    report_dir = POWER_ROOT / bench / flavor / "reports"
    return PowerRecord(
        total_mw=extract_total_power(report_dir / "power_total.rpt"),
        mule_mw=extract_instance_total(report_dir / "power_inst_b.rpt"),
    )


def pct_delta(new: float, old: float) -> float:
    return ((new - old) / old) * 100.0


def format_pct(value: float) -> str:
    return f"{value:+.3f}%"


def main() -> int:
    rows: list[dict[str, object]] = []
    for bench in BENCHMARKS:
        baseline_metrics = RUN_ROOT / bench / "metrics" / "core_hybrid.json"
        switched_metrics = RUN_ROOT / f"{bench}_selective_latency_hidden_mule" / "metrics" / "core_hybrid.json"
        base_cycles = load_cycles(baseline_metrics)
        sw_cycles = load_cycles(switched_metrics)
        base_power = collect_power(bench, "baseline")
        sw_power = collect_power(bench, "selective")
        rows.append(
            {
                "benchmark": bench,
                "baseline_cycles": base_cycles,
                "switched_cycles": sw_cycles,
                "cycle_delta_pct": pct_delta(sw_cycles, base_cycles),
                "baseline_power": base_power.total_mw,
                "switched_power": sw_power.total_mw,
                "power_delta_pct": pct_delta(sw_power.total_mw, base_power.total_mw),
                "u_mule_power": sw_power.mule_mw,
            }
        )

    print("| Benchmark | Baseline Cycles | Selective Switched Cycles | Cycle Delta (%) | Baseline Core Pwr (mW) | Selective Core Pwr (mW) | Core Power Delta (%) | `u_mule` Pwr (mW) |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for row in rows:
        print(
            f"| `{row['benchmark']}` | "
            f"{row['baseline_cycles']} | "
            f"{row['switched_cycles']} | "
            f"`{format_pct(float(row['cycle_delta_pct']))}` | "
            f"{float(row['baseline_power']):.6f} | "
            f"{float(row['switched_power']):.6f} | "
            f"`{format_pct(float(row['power_delta_pct']))}` | "
            f"{float(row['u_mule_power']):.4f} |"
        )

    best_cycle = min(rows, key=lambda row: float(row["cycle_delta_pct"]))
    best_power = min(rows, key=lambda row: float(row["power_delta_pct"]))
    print()
    print(
        f"Best cycle result: `{best_cycle['benchmark']}` at `{format_pct(float(best_cycle['cycle_delta_pct']))}`."
    )
    print(
        f"Largest core power reduction: `{best_power['benchmark']}` at `{format_pct(float(best_power['power_delta_pct']))}`."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

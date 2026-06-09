#!/usr/bin/env python3

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUN_ROOT = ROOT / "outputs" / "job7_exact_free_runs"
POWER_ROOT = ROOT / "outputs" / "job7_exact_free_power"
BASELINE_POWER_ROOT = ROOT / "outputs" / "job6_selective_power"
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


def load_metrics(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def extract_total_power(path: Path) -> float:
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^Total Power:\s+([0-9.]+)$", text, re.M)
    if not match:
        raise RuntimeError(f"missing Total Power in {path}")
    return float(match.group(1))


def pct_delta(new: float, old: float) -> float:
    return ((new - old) / old) * 100.0


def format_pct(value: float) -> str:
    return f"{value:+.3f}%"


def main() -> int:
    rows: list[dict[str, object]] = []
    omitted: list[str] = []
    for bench in BENCHMARKS:
        baseline_metrics_path = RUN_ROOT / bench / "metrics" / "core_hybrid.json"
        oracle_metrics_path = RUN_ROOT / f"{bench}_exact_free_mule" / "metrics" / "core_hybrid.json"
        if not oracle_metrics_path.is_file():
            omitted.append(f"{bench} (missing oracle metrics)")
            continue
        oracle_metrics = load_metrics(oracle_metrics_path)
        if int(oracle_metrics.get("patched_plain_mul_count", 0)) <= 0:
            omitted.append(f"{bench} (zero accepted patches)")
            continue

        baseline_metrics = load_metrics(baseline_metrics_path)
        base_cycles = int(baseline_metrics["metrics"]["sim_total_cycles"])
        oracle_cycles = int(oracle_metrics["metrics"]["sim_total_cycles"])
        if oracle_cycles > base_cycles:
            raise RuntimeError(f"{bench} is not exact-free: {base_cycles} -> {oracle_cycles}")

        baseline_power = extract_total_power(
            BASELINE_POWER_ROOT / bench / "baseline" / "reports" / "power_total.rpt"
        )
        oracle_power = extract_total_power(
            POWER_ROOT / bench / "oracle" / "reports" / "power_total.rpt"
        )
        rows.append(
            {
                "benchmark": bench,
                "baseline_cycles": base_cycles,
                "oracle_cycles": oracle_cycles,
                "cycle_delta_pct": pct_delta(oracle_cycles, base_cycles),
                "baseline_power": baseline_power,
                "oracle_power": oracle_power,
                "power_delta_pct": pct_delta(oracle_power, baseline_power),
                "patches": int(oracle_metrics.get("patched_plain_mul_count", 0)),
            }
        )

    print("| Benchmark | Baseline Cycles | Oracle Switched Cycles | Cycle Delta (%) | Baseline Core Pwr (mW) | Oracle Core Pwr (mW) | Core Power Delta (%) |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for row in rows:
        print(
            f"| `{row['benchmark']}` | "
            f"{row['baseline_cycles']} | "
            f"{row['oracle_cycles']} | "
            f"`{format_pct(float(row['cycle_delta_pct']))}` | "
            f"{float(row['baseline_power']):.6f} | "
            f"{float(row['oracle_power']):.6f} | "
            f"`{format_pct(float(row['power_delta_pct']))}` |"
        )

    print()
    if rows:
        best_power = min(rows, key=lambda row: float(row["power_delta_pct"]))
        if float(best_power["power_delta_pct"]) < 0.0:
            print(
                f"Largest oracle core power reduction: `{best_power['benchmark']}` at "
                f"`{format_pct(float(best_power['power_delta_pct']))}`."
            )
        else:
            print("No accepted exact-free patch reduced total core power.")
    else:
        print("No benchmarks accepted at least one exact-free patch.")
    print("Omitted benchmarks: " + (", ".join(omitted) if omitted else "none"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3.11

from __future__ import annotations

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUN_ROOT = ROOT / "outputs" / "job7_near_free_runs"
POWER_ROOT = ROOT / "outputs" / "job7_near_free_power"
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


def load_metrics(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def extract_total_power(path: Path) -> float:
    text = path.read_text(encoding="utf-8", errors="replace")
    matches = re.findall(r"^Total Power:\s+([0-9.]+)\s*$", text, re.MULTILINE)
    if not matches:
        raise RuntimeError(f"Total Power not found in {path}")
    return float(matches[-1])


def pct_delta(new_value: float, base_value: float) -> float:
    return ((new_value - base_value) / base_value) * 100.0


def format_pct(value: float) -> str:
    return f"{value:+.3f}%"


def main() -> int:
    rows: list[dict[str, object]] = []
    omitted: list[str] = []

    for bench in BENCHMARKS:
        baseline_metrics_path = RUN_ROOT / bench / "metrics" / "core_hybrid.json"
        oracle_metrics_path = RUN_ROOT / f"{bench}_near_free_relaxed_mule" / "metrics" / "core_hybrid.json"
        if not baseline_metrics_path.is_file():
            omitted.append(f"{bench} (missing baseline metrics)")
            continue
        if not oracle_metrics_path.is_file():
            omitted.append(f"{bench} (missing near-free oracle metrics)")
            continue

        baseline_metrics = load_metrics(baseline_metrics_path)
        oracle_metrics = load_metrics(oracle_metrics_path)
        patches = int(oracle_metrics.get("patched_plain_mul_count", 0))
        if patches == 0:
            omitted.append(f"{bench} (zero accepted near-free patches)")
            continue

        base_cycles = int(baseline_metrics["metrics"]["sim_total_cycles"])
        oracle_cycles = int(oracle_metrics["metrics"]["sim_total_cycles"])
        cycle_delta = pct_delta(oracle_cycles, base_cycles)
        tolerance = float(oracle_metrics.get("oracle_cycle_tolerance_pct", 0.5))
        if cycle_delta > tolerance + 1e-9:
            raise RuntimeError(f"{bench} exceeds near-free tolerance: {cycle_delta:.6f}% > {tolerance:.6f}%")

        baseline_power_path = BASELINE_POWER_ROOT / bench / "baseline" / "reports" / "power_total.rpt"
        oracle_power_path = POWER_ROOT / bench / "oracle" / "reports" / "power_total.rpt"
        if not oracle_power_path.is_file():
            omitted.append(f"{bench} ({patches} accepted patches, missing near-free oracle power)")
            continue

        baseline_power = extract_total_power(baseline_power_path)
        oracle_power = extract_total_power(oracle_power_path)
        rows.append(
            {
                "benchmark": bench,
                "baseline_cycles": base_cycles,
                "oracle_cycles": oracle_cycles,
                "cycle_delta_pct": cycle_delta,
                "baseline_power": baseline_power,
                "oracle_power": oracle_power,
                "power_delta_pct": pct_delta(oracle_power, baseline_power),
                "patches": patches,
                "retired_mule": int(oracle_metrics["metrics"].get("retired_mule", 0)),
            }
        )

    print("| Benchmark | Baseline Cycles | Near-Free Cycles | Cycle Delta (%) | Accepted Patches | Retired MULE | Baseline Core Pwr (mW) | Near-Free Core Pwr (mW) | Core Power Delta (%) |")
    print("| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
    for row in rows:
        print(
            f"| `{row['benchmark']}` | "
            f"{row['baseline_cycles']} | "
            f"{row['oracle_cycles']} | "
            f"`{format_pct(float(row['cycle_delta_pct']))}` | "
            f"{row['patches']} | "
            f"{row['retired_mule']} | "
            f"{float(row['baseline_power']):.6f} | "
            f"{float(row['oracle_power']):.6f} | "
            f"`{format_pct(float(row['power_delta_pct']))}` |"
        )

    print()
    if rows:
        best_power = min(rows, key=lambda row: float(row["power_delta_pct"]))
        best_cycle = min(rows, key=lambda row: float(row["cycle_delta_pct"]))
        if float(best_power["power_delta_pct"]) < 0:
            print(
                f"Largest near-free core power reduction: `{best_power['benchmark']}` at "
                f"`{format_pct(float(best_power['power_delta_pct']))}`."
            )
        else:
            print("No near-free benchmark reduced total core power.")
            print(
                f"Best near-free core power delta: `{best_power['benchmark']}` at "
                f"`{format_pct(float(best_power['power_delta_pct']))}`."
            )
        print(
            f"Lowest near-free cycle penalty: `{best_cycle['benchmark']}` at "
            f"`{format_pct(float(best_cycle['cycle_delta_pct']))}`."
        )
    else:
        print("No benchmarks accepted at least one near-free patch with power reports.")
    print("Omitted benchmarks: " + (", ".join(omitted) if omitted else "none"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

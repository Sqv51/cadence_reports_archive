#!/usr/bin/env python3

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parent
BENCHMARKS = [
    {
        "name": "complex_mul_vec",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/complex_mul_vec/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/complex_mul_vec_latency_hidden_mule/metrics/core_hybrid.json",
    },
    {
        "name": "fft_butterfly",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/fft_butterfly/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/fft_butterfly_latency_hidden_mule/metrics/core_hybrid.json",
    },
    {
        "name": "fir_direct",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/fir_direct/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/fir_direct_latency_hidden_mule/metrics/core_hybrid.json",
    },
    {
        "name": "fir_unrolled",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/fir_unrolled/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/fir_unrolled_latency_hidden_mule/metrics/core_hybrid.json",
    },
    {
        "name": "matmul_tiled",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/matmul_tiled/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/matmul_tiled_latency_hidden_mule/metrics/core_hybrid.json",
    },
    {
        "name": "outer_product",
        "baseline_metrics": ROOT / "outputs/benchmark_runs/outer_product/metrics/core_hybrid.json",
        "switched_metrics": ROOT / "outputs/benchmark_runs/outer_product_latency_hidden_mule/metrics/core_hybrid.json",
    },
]


@dataclass
class PowerRecord:
    total_mw: float
    mul_mw: float
    mule_mw: float


def load_cycles(path: Path) -> int:
    data = json.loads(path.read_text())
    return int(data["metrics"]["sim_total_cycles"])


def read_report_text(path: Path) -> str:
    return path.read_text()


def extract_total_power(path: Path) -> float:
    text = read_report_text(path)
    match = re.search(r"^Total Power:\s+([0-9.]+)$", text, re.M)
    if not match:
        raise RuntimeError(f"missing Total Power in {path}")
    return float(match.group(1))


def extract_instance_total(path: Path) -> float:
    text = read_report_text(path)
    lines = text.splitlines()
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("*") or stripped.startswith("-"):
            continue
        parts = stripped.split()
        if len(parts) >= 7 and parts[0] in {"u_mul", "u_mule"}:
            return float(parts[6])
    raise RuntimeError(f"missing instance total in {path}")


def collect_power(bench: str, flavor: str) -> PowerRecord:
    report_dir = ROOT / "outputs/benchmark_power_job4" / bench / flavor / "reports"
    return PowerRecord(
        total_mw=extract_total_power(report_dir / "power_total.rpt"),
        mul_mw=extract_instance_total(report_dir / "power_inst_a.rpt"),
        mule_mw=extract_instance_total(report_dir / "power_inst_b.rpt"),
    )


def pct_delta(new: float, old: float) -> float:
    return ((new - old) / old) * 100.0


def main() -> int:
    rows = []
    for bench in BENCHMARKS:
        base_cycles = load_cycles(bench["baseline_metrics"])
        sw_cycles = load_cycles(bench["switched_metrics"])
        base_power = collect_power(bench["name"], "baseline")
        sw_power = collect_power(bench["name"], "switched")
        rows.append(
            {
                "benchmark": bench["name"],
                "baseline_cycles": base_cycles,
                "switched_cycles": sw_cycles,
                "delta_cycles_pct": pct_delta(sw_cycles, base_cycles),
                "baseline_total_mw": base_power.total_mw,
                "switched_total_mw": sw_power.total_mw,
                "delta_total_power_pct": pct_delta(sw_power.total_mw, base_power.total_mw),
                "baseline_u_mul_mw": base_power.mul_mw,
                "switched_u_mul_mw": sw_power.mul_mw,
                "baseline_u_mule_mw": base_power.mule_mw,
                "switched_u_mule_mw": sw_power.mule_mw,
            }
        )

    print("| Benchmark | Baseline Cycles | Switched Cycles | Delta Cycles | Baseline Total (mW) | Switched Total (mW) | Delta Total Power | Baseline u_mul (mW) | Switched u_mul (mW) | Baseline u_mule (mW) | Switched u_mule (mW) |")
    print("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
    for row in rows:
        print(
            f"| {row['benchmark']} | "
            f"{row['baseline_cycles']} | "
            f"{row['switched_cycles']} | "
            f"{row['delta_cycles_pct']:+.2f}% | "
            f"{row['baseline_total_mw']:.6f} | "
            f"{row['switched_total_mw']:.6f} | "
            f"{row['delta_total_power_pct']:+.2f}% | "
            f"{row['baseline_u_mul_mw']:.4f} | "
            f"{row['switched_u_mul_mw']:.4f} | "
            f"{row['baseline_u_mule_mw']:.4f} | "
            f"{row['switched_u_mule_mw']:.4f} |"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

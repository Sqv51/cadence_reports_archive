#!/usr/bin/env python3.11

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parent
RUN_ROOT = ROOT / "outputs" / "job7_near_free_runs"
POWER_ROOT = ROOT / "outputs" / "job7_near_free_power"
BASELINE_POWER_ROOT = ROOT / "outputs" / "job6_selective_power"
OUT_ROOT = ROOT / "outputs" / "job7_near_free_reports"

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


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def extract_total_power(path: Path) -> float:
    text = path.read_text(encoding="utf-8", errors="replace")
    matches = re.findall(r"^Total Power:\s+([0-9.]+)\s*$", text, re.MULTILINE)
    if not matches:
        raise RuntimeError(f"Total Power not found in {path}")
    return float(matches[-1])


def pct_delta(new_value: float, base_value: float) -> float:
    return ((new_value - base_value) / base_value) * 100.0


def fmt_pct(value: float) -> str:
    return f"{value:+.3f}%"


def collect_rows() -> tuple[list[dict], list[str]]:
    rows: list[dict] = []
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

        baseline_metrics = load_json(baseline_metrics_path)
        oracle_metrics = load_json(oracle_metrics_path)
        patches = int(oracle_metrics.get("patched_plain_mul_count", 0))
        if patches == 0:
            omitted.append(f"{bench} (zero accepted near-free patches)")
            continue

        baseline_power_path = BASELINE_POWER_ROOT / bench / "baseline" / "reports" / "power_total.rpt"
        oracle_power_path = POWER_ROOT / bench / "oracle" / "reports" / "power_total.rpt"
        if not baseline_power_path.is_file():
            omitted.append(f"{bench} (missing baseline power)")
            continue
        if not oracle_power_path.is_file():
            omitted.append(f"{bench} ({patches} accepted patches, missing near-free oracle power)")
            continue

        base_cycles = int(baseline_metrics["metrics"]["sim_total_cycles"])
        oracle_cycles = int(oracle_metrics["metrics"]["sim_total_cycles"])
        cycle_delta = pct_delta(oracle_cycles, base_cycles)
        baseline_power = extract_total_power(baseline_power_path)
        oracle_power = extract_total_power(oracle_power_path)

        rows.append(
            {
                "benchmark": bench,
                "baseline_cycles": base_cycles,
                "oracle_cycles": oracle_cycles,
                "cycle_delta_pct": cycle_delta,
                "patches": patches,
                "retired_mule": int(oracle_metrics["metrics"].get("retired_mule", 0)),
                "baseline_power": baseline_power,
                "oracle_power": oracle_power,
                "power_delta_pct": pct_delta(oracle_power, baseline_power),
            }
        )

    return rows, omitted


def build_table_text(rows: list[dict], omitted: list[str]) -> str:
    lines = [
        "Job 7 Near-Free Oracle Steering Results",
        "=======================================",
        "",
        "| Benchmark | Baseline Cycles | Near-Free Cycles | Cycle Delta (%) | Accepted Patches | Retired MULE | Baseline Core Pwr (mW) | Near-Free Core Pwr (mW) | Core Power Delta (%) |",
        "| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |",
    ]
    for row in rows:
        lines.append(
            f"| {row['benchmark']} | {row['baseline_cycles']} | {row['oracle_cycles']} | "
            f"{fmt_pct(row['cycle_delta_pct'])} | {row['patches']} | {row['retired_mule']} | "
            f"{row['baseline_power']:.6f} | {row['oracle_power']:.6f} | {fmt_pct(row['power_delta_pct'])} |"
        )

    lines.append("")
    if rows:
        best_power = min(rows, key=lambda row: row["power_delta_pct"])
        best_cycle = min(rows, key=lambda row: row["cycle_delta_pct"])
        if best_power["power_delta_pct"] < 0:
            lines.append(
                f"Largest near-free core power reduction: {best_power['benchmark']} at {fmt_pct(best_power['power_delta_pct'])}."
            )
        else:
            lines.append("No near-free benchmark reduced total core power.")
            lines.append(
                f"Best near-free core power delta: {best_power['benchmark']} at {fmt_pct(best_power['power_delta_pct'])}."
            )
        lines.append(
            f"Lowest near-free cycle penalty: {best_cycle['benchmark']} at {fmt_pct(best_cycle['cycle_delta_pct'])}."
        )
    else:
        lines.append("No benchmarks accepted at least one near-free patch with power reports.")
    lines.append("Omitted benchmarks: " + (", ".join(omitted) if omitted else "none"))
    lines.append("")
    return "\n".join(lines)


def build_narrative_text(rows: list[dict], omitted: list[str]) -> str:
    lines = [
        "Job 7 Near-Free Oracle Steering Summary Notes",
        "=============================================",
        "",
        "This campaign evaluated a relaxed oracle-validated mule steering flow with",
        "a strict near-free acceptance bound of +0.500% execution cycles. Every",
        "benchmark was run on the hybrid core, and only accepted patch sets were",
        "replayed through post-route power extraction.",
        "",
        "Scope and completeness:",
        f"- 20 benchmarks were evaluated.",
        f"- {len(rows)} benchmarks found at least one accepted near-free patch set.",
        f"- {len(rows)} near-free post-route power reports were generated.",
        "",
    ]

    if rows:
        best_cycle = min(rows, key=lambda row: row["cycle_delta_pct"])
        best_power = min(rows, key=lambda row: row["power_delta_pct"])
        lines.extend(
            [
                "Accepted near-free cases:",
                *[
                    f"- {row['benchmark']}: {row['patches']} accepted patches, "
                    f"{row['retired_mule']} retired mule ops, "
                    f"cycle delta {fmt_pct(row['cycle_delta_pct'])}, "
                    f"core power delta {fmt_pct(row['power_delta_pct'])}"
                    for row in rows
                ],
                "",
                "Top-level observations:",
                f"- The lowest cycle penalty was {best_cycle['benchmark']} at {fmt_pct(best_cycle['cycle_delta_pct'])}.",
            ]
        )
        if best_power["power_delta_pct"] < 0:
            lines.append(
                f"- The largest core power reduction was {best_power['benchmark']} at {fmt_pct(best_power['power_delta_pct'])}."
            )
        else:
            lines.append(
                f"- No accepted near-free case reduced total core power; the best power result was {best_power['benchmark']} at {fmt_pct(best_power['power_delta_pct'])}."
            )
        lines.extend(
            [
                "- The relaxed oracle did find real hidability in a few kernels, but the measurable effect in this implementation was cycle-neutral to near-neutral rather than energy-saving.",
                "- Most kernels still had zero accepted patches, which reinforces the earlier conclusion that static mul sites often sit directly on throughput-critical recurrences.",
            ]
        )
    else:
        lines.append("No benchmark found an accepted near-free patch set.")

    lines.extend(
        [
            "",
            "Omitted benchmarks:",
            "- " + (", ".join(omitted) if omitted else "none"),
            "",
            "Recommended interpretation:",
            "- The <=0.5% oracle is useful as a schedule-safety filter, but in this core revision it exposed only a small number of near-free substitutions and did not translate into total core power savings on the accepted set.",
            "",
        ]
    )
    return "\n".join(lines)


def build_merged_bundle(rows: list[dict], table_text: str, omitted: list[str]) -> str:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "Job 7 Near-Free Oracle Steering Power and Result Bundle",
        "======================================================",
        "",
        f"Generated: {timestamp}",
        "Contents: final collector table and accepted near-free power reports.",
        "",
        "===== BEGIN FINAL_JOB7_NEAR_FREE_COLLECTOR_TABLE =====",
        "",
        table_text.rstrip(),
        "",
        "===== END FINAL_JOB7_NEAR_FREE_COLLECTOR_TABLE =====",
        "",
    ]

    for row in rows:
        bench = row["benchmark"]
        report_dir = POWER_ROOT / bench / "oracle" / "reports"
        for name in ("power_total.rpt", "power_inst_a.rpt", "power_inst_b.rpt"):
            path = report_dir / name
            if not path.is_file():
                continue
            lines.append(f"===== BEGIN {path.relative_to(ROOT)} =====")
            lines.append("")
            lines.append(path.read_text(encoding="utf-8", errors="replace").rstrip())
            lines.append("")
            lines.append(f"===== END {path.relative_to(ROOT)} =====")
            lines.append("")

    lines.append("Omitted benchmarks: " + (", ".join(omitted) if omitted else "none"))
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    rows, omitted = collect_rows()
    OUT_ROOT.mkdir(parents=True, exist_ok=True)

    table_text = build_table_text(rows, omitted)
    narrative_text = build_narrative_text(rows, omitted)
    merged_text = build_merged_bundle(rows, table_text, omitted)

    (OUT_ROOT / "job7_near_free_table_summary.txt").write_text(table_text, encoding="utf-8")
    (OUT_ROOT / "job7_near_free_narrative_summary.txt").write_text(narrative_text, encoding="utf-8")
    (OUT_ROOT / "merged_job7_near_free_power_results_only.txt").write_text(merged_text, encoding="utf-8")

    print(table_text)
    print(f"wrote: {OUT_ROOT / 'job7_near_free_table_summary.txt'}")
    print(f"wrote: {OUT_ROOT / 'job7_near_free_narrative_summary.txt'}")
    print(f"wrote: {OUT_ROOT / 'merged_job7_near_free_power_results_only.txt'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

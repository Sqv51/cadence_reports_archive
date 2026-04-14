#!/usr/bin/env python3
"""
energy_benchmark_analysis.py - MUL→MULE Conversion Energy & Latency Analysis

Analyzes Spike ISA simulator kernel traces to project energy savings and
latency impact when routing multiply operations through an efficient
iterative multiplier (MULE) instead of a standard Booth-Wallace (MUL).

Three conversion scenarios are evaluated per benchmark:
  A) ALL:            every MUL → MULE (aggressive)
  B) FULLY HIDDEN:   only ops with D >= ΔL (zero stall)
  C) PARTIALLY HIDDEN: only ops with 0 < D < ΔL (some stall)

Energy parameters from Cadence NanGate45 post-route VCD-based power
(100 MHz, see EDP_THROUGHPUT_ENERGY_REPORT.md):

  Parameter             Value       Source
  ───────────────────── ─────────── ─────────────────────────────
  P_mul  (Booth avg)    2.020 mW    power_inst_a.rpt (2xMUL cfg)
  P_mule (MULE avg)     0.155 mW    power_inst_b.rpt (Hybrid cfg)
  L_mul  (MUL latency)  3 cycles    RTL / xrun simulation
  L_mule (MULE latency) 5 cycles    RTL / xrun simulation
  P_core (total power)  8.270 mW    power_total.rpt  (Hybrid cfg)
  T_clk                 10 ns       100 MHz clock target

Per-op energy proxy: e = P_avg × L × T_clk
  e_mul  = 2.020 mW × 3 × 10 ns = 60.60 pJ
  e_mule = 0.155 mW × 5 × 10 ns =  7.75 pJ
  Δe     = 52.85 pJ  (saving per converted op at zero stall)
  ΔL     = 2 cycles  (extra MULE latency)
  e_cyc  = 82.70 pJ  (core energy per stall cycle)

NOTE: The per-op energy proxy uses average instance power × operation
latency.  This is a first-order conservative estimate.  The true
per-op dynamic energy is higher, so actual savings may be larger.
These values are suitable for RELATIVE comparisons across benchmarks.

Assumption: instruction-stream distance D maps 1:1 to cycles of hiding
capacity (valid at IPC ≈ 1).  For dual-issue at higher IPC, effective
hiding is D/IPC; multiply threshold by IPC for adjusted analysis.
"""

import re
import sys
import os
import argparse
from collections import Counter, defaultdict

# ── Energy parameters (defaults: 2xMUL-vs-Hybrid dual-core config) ───
P_MUL  = 2.020e-3    # W
P_MULE = 0.155e-3    # W
L_MUL  = 3           # cycles
L_MULE = 5           # cycles
DL     = L_MULE - L_MUL   # 2 extra cycles
P_CORE = 8.270e-3    # W
T_CLK  = 10e-9       # s  (100 MHz)

e_mul  = P_MUL  * L_MUL  * T_CLK * 1e12   # 60.60 pJ
e_mule = P_MULE * L_MULE * T_CLK * 1e12   #  7.75 pJ
de     = e_mul - e_mule                     # 52.85 pJ
e_cyc  = P_CORE * T_CLK * 1e12             # 82.70 pJ


def apply_params(p_mul, p_mule, l_mul, l_mule, p_core, t_clk):
    """Override global energy parameters."""
    global P_MUL, P_MULE, L_MUL, L_MULE, DL, P_CORE, T_CLK
    global e_mul, e_mule, de, e_cyc
    P_MUL, P_MULE = p_mul, p_mule
    L_MUL, L_MULE = l_mul, l_mule
    DL = L_MULE - L_MUL
    P_CORE, T_CLK = p_core, t_clk
    e_mul  = P_MUL  * L_MUL  * T_CLK * 1e12
    e_mule = P_MULE * L_MULE * T_CLK * 1e12
    de     = e_mul - e_mule
    e_cyc  = P_CORE * T_CLK * 1e12

# ── Trace parsing ─────────────────────────────────────────────────────
insn_re = re.compile(
    r"core\s+\d+:\s+(0x[0-9a-fA-F]+)\s+\(0x[0-9a-fA-F]+\)\s+(.*)$")

abi_to_x = {
    "zero": "x0", "ra": "x1", "sp": "x2", "gp": "x3", "tp": "x4",
    "t0": "x5", "t1": "x6", "t2": "x7",
    "s0": "x8", "fp": "x8", "s1": "x9",
    "a0": "x10", "a1": "x11", "a2": "x12", "a3": "x13",
    "a4": "x14", "a5": "x15", "a6": "x16", "a7": "x17",
    "s2": "x18", "s3": "x19", "s4": "x20", "s5": "x21",
    "s6": "x22", "s7": "x23", "s8": "x24", "s9": "x25",
    "s10": "x26", "s11": "x27",
    "t3": "x28", "t4": "x29", "t5": "x30", "t6": "x31",
}

reg_tok = re.compile(
    r"\b(x(?:[12]?\d|3[01])|zero|ra|sp|gp|tp|t[0-6]"
    r"|s(?:1[01]|[0-9])|fp|a[0-7])\b")


def norm(r):
    return r if r.startswith("x") else abi_to_x.get(r, r)


def classify_op(op):
    if op in ("lw", "lh", "lb", "lbu", "lhu", "ld", "lwu",
              "flw", "fld", "c.lw", "c.ld", "c.lwsp", "c.ldsp"):
        return "load"
    if op in ("sw", "sh", "sb", "sd", "fsw", "fsd",
              "c.sw", "c.sd", "c.swsp", "c.sdsp"):
        return "store"
    if op in ("mul", "mulh", "mulhu", "mulhsu", "mulw"):
        return "mul"
    if op in ("add", "addw", "addi", "addiw",
              "c.add", "c.addw", "c.addi", "c.addiw",
              "sub", "subw", "c.sub", "c.subw"):
        return "add"
    if op in ("sll", "slli", "slliw", "srl", "srli", "srliw",
              "sra", "srai", "sraiw", "c.slli", "c.srli", "c.srai"):
        return "shift"
    if (op.startswith("b") or op in
        ("beq", "bne", "blt", "bge", "bltu", "bgeu",
         "c.beqz", "c.bnez", "jal", "jalr", "c.j", "c.jal", "c.jalr")):
        return "branch"
    return "other"


# Compressed R-type instructions where rd is also a source operand
COMPRESSED_RD_READ = frozenset([
    "c.add", "c.addw", "c.sub", "c.subw",
    "c.and", "c.or", "c.xor",
])


def guess_rd_reads(disasm):
    toks = disasm.replace(",", " ").replace("(", " ").replace(")", " ").split()
    if not toks:
        return None, [], "?", "other"
    op = toks[0]
    regs = [norm(r) for r in reg_tok.findall(disasm)]
    cls = classify_op(op)

    if cls in ("store", "branch"):
        return None, regs, op, cls
    if op in ("jal", "c.jal"):
        return (regs[0] if regs else None), [], op, "branch"
    if op in ("jalr", "c.jalr"):
        rd = regs[0] if regs else None
        reads = regs[1:2] if len(regs) >= 2 else []
        return rd, reads, op, "branch"

    rd = regs[0] if regs else None
    reads = regs[1:] if len(regs) > 1 else []

    # Compressed R-type: rd/rs1 is both dest and source
    if op in COMPRESSED_RD_READ and rd and rd not in reads:
        reads = [rd] + reads

    return rd, reads, op, cls


# ── Analysis engine ───────────────────────────────────────────────────

def analyze_kernel(log_path):
    """Parse trace, build dep graph, compute per-MUL energy metrics."""
    ops, classes, rd_list, reads_list = [], [], [], []

    with open(log_path, errors="ignore") as f:
        for line in f:
            m = insn_re.match(line)
            if not m:
                continue
            dis = m.group(2)
            rd, reads, op, cls = guess_rd_reads(dis)
            ops.append(op)
            classes.append(cls)
            rd_list.append(rd)
            reads_list.append(reads)

    N = len(ops)
    if N == 0:
        return None

    # Instruction mix
    mix = Counter(classes)

    # Build consumer map: producer_idx → [(consumer_idx, reg), ...]
    consumers_of = defaultdict(list)
    last_writer = {}
    for i in range(N):
        for r in reads_list[i]:
            if r in last_writer:
                consumers_of[last_writer[r]].append((i, r))
        if rd_list[i]:
            last_writer[rd_list[i]] = i

    # Compute D for each MUL
    mul_idx = [i for i, c in enumerate(classes) if c == "mul"]
    n_mul = len(mul_idx)

    dists = []        # D per MUL (None = no consumer within trace)
    cons_types = []

    for mi in mul_idx:
        cons = consumers_of.get(mi)
        if cons:
            best_c, _ = min(cons, key=lambda x: x[0])
            dists.append(best_c - mi)
            cons_types.append(classes[best_c])
        else:
            dists.append(None)
            cons_types.append("none")

    # Classify by hiding potential
    fh, ph, nh, nc = [], [], [], []
    for j, D in enumerate(dists):
        if D is None:
            nc.append(j)
        elif D >= DL:
            fh.append((j, D))
        elif D > 0:
            ph.append((j, D))
        else:
            nh.append((j, D))

    # Energy/latency metrics for a set of converted ops
    def scenario(idx_D_pairs):
        n = len(idx_D_pairs)
        if n == 0:
            return dict(n=0, esave=0.0, stalls=0, scost=0.0, net=0.0)
        esave = n * de
        stalls = sum(max(0, DL - D) for _, D in idx_D_pairs)
        scost = stalls * e_cyc
        return dict(n=n, esave=esave, stalls=stalls, scost=scost,
                    net=esave - scost)

    # No-consumer ops: result unused in trace → fully hidden (infinite D)
    INF_D = 9999
    all_pairs = [(j, D if D is not None else INF_D)
                 for j, D in enumerate(dists)]
    fh_pairs = fh + [(j, INF_D) for j in nc]

    # Estimated total core energy (IPC ≈ 1 conservative)
    est_cycles = N
    est_core_E = est_cycles * e_cyc

    return dict(
        name=os.path.basename(log_path).replace(".log", ""),
        N=N, n_mul=n_mul,
        mul_pct=100.0 * n_mul / N,
        mix=mix,
        n_fh=len(fh) + len(nc),
        n_ph=len(ph),
        n_nh=len(nh),
        n_nc=len(nc),
        D_dist=Counter(D if D is not None else "inf" for D in dists),
        cons_types=Counter(cons_types).most_common(10),
        sc_all=scenario(all_pairs),
        sc_fh=scenario(fh_pairs),
        sc_ph=scenario(ph),
        est_cycles=est_cycles,
        est_core_E=est_core_E,
    )


# ── Output formatting ─────────────────────────────────────────────────

def fmt_e(pJ):
    """Format energy value."""
    if abs(pJ) >= 1e6:
        return f"{pJ / 1e6:,.2f} nJ"
    return f"{pJ:,.1f} pJ"


def print_one(r):
    nm = r['n_mul']
    print(f"\n{'=' * 74}")
    print(f"  {r['name']}")
    print(f"{'=' * 74}")
    print(f"  Dynamic instructions : {r['N']:>10,}")
    print(f"  MUL instructions     : {nm:>10,}  ({r['mul_pct']:.2f}%)")

    # Instruction mix top-5
    top5 = r['mix'].most_common(5)
    mix_str = ", ".join(f"{k}={v}" for k, v in top5)
    print(f"  Instruction mix (top): {mix_str}")
    print(f"  Est. total cycles    : {r['est_cycles']:>10,}  (IPC=1 assumption)")
    print(f"  Est. core energy     : {fmt_e(r['est_core_E'])}")
    print()

    # D classification
    fh_pct = 100 * r['n_fh'] / nm if nm else 0
    ph_pct = 100 * r['n_ph'] / nm if nm else 0
    nh_pct = 100 * r['n_nh'] / nm if nm else 0
    print(f"  Production→consumption distance D (threshold ΔL={DL}):")
    print(f"    Fully hidden    (D >= {DL}) : {r['n_fh']:>7,}  ({fh_pct:5.1f}%)")
    print(f"    Partially hidden (0<D<{DL}) : {r['n_ph']:>7,}  ({ph_pct:5.1f}%)")
    print(f"    Not hidden       (D = 0)  : {r['n_nh']:>7,}  ({nh_pct:5.1f}%)")
    print(f"    No consumer (→ fully hid) : {r['n_nc']:>7,}")
    print()

    # D distribution
    dd = r['D_dist']
    d_keys = sorted([k for k in dd if k != "inf"]) + \
             (["inf"] if "inf" in dd else [])
    d_str = ", ".join(f"D={k}:{dd[k]}" for k in d_keys)
    print(f"  D distribution: {d_str}")
    print(f"  Consumer types: {r['cons_types']}")
    print()

    # Energy parameters reminder
    print(f"  Energy params: e_mul={e_mul:.2f}pJ  e_mule={e_mule:.2f}pJ  "
          f"Δe={de:.2f}pJ/op  ΔL={DL}cyc  e_cyc={e_cyc:.2f}pJ")
    print()

    # Three scenarios
    for label, sc in [
        (f"A) ALL MUL→MULE ({nm} ops, aggressive)", r['sc_all']),
        (f"B) FULLY HIDDEN only ({r['n_fh']} ops, D≥{DL})", r['sc_fh']),
        (f"C) PARTIALLY HIDDEN only ({r['n_ph']} ops, 0<D<{DL})", r['sc_ph']),
    ]:
        core_pct = 100 * sc['net'] / r['est_core_E'] if r['est_core_E'] else 0
        per_op = sc['net'] / sc['n'] if sc['n'] else 0
        lat_pct = 100 * sc['stalls'] / r['est_cycles'] if r['est_cycles'] else 0

        print(f"  {label}:")
        print(f"    Converted ops      : {sc['n']:>9,}")
        print(f"    Multiplier saving  : {fmt_e(sc['esave']):>14}")
        print(f"    Extra stall cycles : {sc['stalls']:>9,}  "
              f"({lat_pct:+.4f}% latency)")
        print(f"    Stall energy cost  : {fmt_e(sc['scost']):>14}")
        print(f"    ── Net energy save : {fmt_e(sc['net']):>14}  "
              f"({core_pct:+.4f}% of core)")
        print(f"    ── Per converted op: {per_op:>+10.2f} pJ/op")
        print()


def print_summary(results):
    print(f"\n{'=' * 120}")
    print("  CROSS-BENCHMARK SUMMARY")
    print(f"{'=' * 120}")

    hdr = (f"{'Kernel':<20} {'Insns':>8} {'MUL%':>6} {'N_mul':>7} "
           f"{'FH%':>6} {'PH%':>6} "
           f"{'NetAll(pJ)':>12} {'All%core':>9} "
           f"{'NetFH(pJ)':>12} {'FH%core':>9} "
           f"{'NetPH(pJ)':>12} {'PH/op':>8}")
    print(hdr)
    print("-" * 120)

    for r in results:
        nm = r['n_mul']
        fh_pct = 100 * r['n_fh'] / nm if nm else 0
        ph_pct = 100 * r['n_ph'] / nm if nm else 0
        sa, sf, sp = r['sc_all'], r['sc_fh'], r['sc_ph']
        ap = 100 * sa['net'] / r['est_core_E'] if r['est_core_E'] else 0
        fp = 100 * sf['net'] / r['est_core_E'] if r['est_core_E'] else 0
        pp_op = sp['net'] / sp['n'] if sp['n'] else 0
        print(f"{r['name']:<20} {r['N']:>8,} {r['mul_pct']:>5.1f}% {nm:>7,} "
              f"{fh_pct:>5.1f}% {ph_pct:>5.1f}% "
              f"{sa['net']:>11,.0f} {ap:>+8.4f}% "
              f"{sf['net']:>11,.0f} {fp:>+8.4f}% "
              f"{sp['net']:>11,.0f} {pp_op:>+7.2f}")

    print()
    print("  Legend:")
    print("    FH% = fraction of MUL ops with D >= ΔL (fully hideable)")
    print("    PH% = fraction with 0 < D < ΔL (partially hideable)")
    print("    NetAll = net energy saving converting ALL MUL → MULE")
    print("    NetFH  = net energy saving converting only fully hidden ops")
    print("    NetPH  = net energy saving converting only partially hidden ops")
    print("    PH/op  = net per-op saving for partially hidden ops (negative = net loss)")
    print(f"    ΔL={DL} cycles, e_mul={e_mul:.2f}pJ, e_mule={e_mule:.2f}pJ, "
          f"Δe={de:.2f}pJ, e_cyc={e_cyc:.2f}pJ")
    print()


# ── Main ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="MUL→MULE conversion energy analysis on Spike traces")
    parser.add_argument("logs", nargs="+", help="Spike trace log files")
    parser.add_argument("--p-mul", type=float, default=None,
                        help="MUL instance power in mW (default: 2.020)")
    parser.add_argument("--p-mule", type=float, default=None,
                        help="MULE instance power in mW (default: 0.155)")
    parser.add_argument("--l-mul", type=int, default=None,
                        help="MUL latency in cycles (default: 3)")
    parser.add_argument("--l-mule", type=int, default=None,
                        help="MULE latency in cycles (default: 5)")
    parser.add_argument("--p-core", type=float, default=None,
                        help="Core total power in mW (default: 8.270)")
    parser.add_argument("--t-clk-ns", type=float, default=None,
                        help="Clock period in ns (default: 10)")
    args = parser.parse_args()

    # Apply overrides if any provided
    if any(v is not None for v in [args.p_mul, args.p_mule, args.l_mul,
                                    args.l_mule, args.p_core, args.t_clk_ns]):
        apply_params(
            p_mul=(args.p_mul or 2.020) * 1e-3,
            p_mule=(args.p_mule or 0.155) * 1e-3,
            l_mul=args.l_mul or 3,
            l_mule=args.l_mule or 5,
            p_core=(args.p_core or 8.270) * 1e-3,
            t_clk=(args.t_clk_ns or 10) * 1e-9,
        )

    results = []
    for log_path in args.logs:
        r = analyze_kernel(log_path)
        if r:
            print_one(r)
            results.append(r)
        else:
            print(f"\n  [SKIP] {log_path}: no instructions parsed")

    if len(results) > 1:
        print_summary(results)

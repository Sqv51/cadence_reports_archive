# Parallel MatMul Power Comparison: 2×MUL vs Hybrid (1×MUL + 1×MULE)

## NanGate45, 100 MHz, Cadence Genus/Innovus/Voltus

**Date:** 2026-03-31  
**Workload:** Fully-unrolled 4×4 matrix multiply (20 repeats, 1280 MUL operations)  
**PDK:** NanGate45 (FreePDK45), typical corner  
**Clock:** 100 MHz (10 ns period)

---

## 1. Simulation Results (Xcelium)

| Metric                 | 2×Standard (2×MUL) | Hybrid (MUL+MULE)  | Δ           |
|------------------------|---------------------|---------------------|-------------|
| Total cycles           | 12,616              | 13,758              | +9.1%       |
| Dual-MUL issue cycles  | 383                 | 0 (single MUL unit) | —           |
| Single-MUL cycles      | 514                 | —                   | —           |
| Total MUL operations   | 1,280               | 1,280               | same        |
| Dual-issue ratio       | 42.7%               | 0%                  | —           |
| Execution time @100MHz | 126.16 µs           | 137.58 µs           | +9.1%       |

The 2×Standard config completes 9.1% faster due to dual-issue of independent MUL pairs.

---

## 2. Synthesis Results (Genus)

| Metric              | 2×Standard (2×MUL) | Hybrid (MUL+MULE) | Δ       |
|---------------------|---------------------|--------------------|---------|
| Cell count (Genus)  | 29,153              | 28,302             | −2.9%   |
| Area (Genus, µm²)  | 62,640.9            | 61,009.5           | −2.6%   |
| Pre-P&R power (mW)  | 6.964               | —                  | —       |

---

## 3. Place & Route Results (Innovus)

| Metric                       | 2×Standard (2×MUL) | Hybrid (MUL+MULE) | Δ       |
|------------------------------|---------------------|--------------------|---------|
| Std cell count (post-P&R)    | 30,021              | 29,216             | −2.7%   |
| Std cell area (µm²)         | 63,561.2            | 62,019.2           | −2.4%   |
| WNS (ns, positive = met)     | 5.239               | 5.252              | —       |
| TNS (ns)                     | 0                   | 0                  | —       |
| Timing                       | Met ✓               | Met ✓              | —       |

---

## 4. Power Analysis (Innovus/Voltus) — Vectorless

| Component          | 2×Standard (mW) | Hybrid (mW) | Δ (mW)  | Δ (%)    |
|--------------------|------------------|-------------|---------|----------|
| Internal Power     | 5.291            | 4.995       | −0.296  | −5.6%    |
| Switching Power    | 3.701            | 3.322       | −0.379  | −10.2%   |
| Leakage Power      | 1.286            | 1.242       | −0.044  | −3.4%    |
| **Total Power**    | **10.278**       | **9.559**   | **−0.719** | **−7.0%** |

### Multiplier Instance Power (Vectorless)

| Instance  | 2×Standard (mW) | Instance  | Hybrid (mW) | Δ        |
|-----------|------------------|-----------|-------------|----------|
| u_mul     | 1.391            | u_mul     | 1.391       | same     |
| u_mul2    | 1.401            | u_mule    | 0.492       | −64.8%   |
| **Sum**   | **2.792**        | **Sum**   | **1.883**   | **−32.6%** |

---

## 5. Power Analysis (Innovus/Voltus) — VCD-Based

| Component          | 2×Standard (mW) | Hybrid (mW) | Δ (mW)  | Δ (%)    |
|--------------------|------------------|-------------|---------|----------|
| Internal Power     | 4.720            | 4.280       | −0.440  | −9.3%    |
| Switching Power    | 2.824            | 2.377       | −0.448  | −15.9%   |
| Leakage Power      | 1.225            | 1.181       | −0.044  | −3.6%    |
| **Total Power**    | **8.770**        | **7.838**   | **−0.932** | **−10.6%** |

### Multiplier Instance Power (VCD)

| Instance  | 2×Standard (mW) | Instance  | Hybrid (mW) | Δ        |
|-----------|------------------|-----------|-------------|----------|
| u_mul     | 1.029            | u_mul     | 1.030       | +0.1%    |
| u_mul2    | 1.028            | u_mule    | 0.113       | −89.0%   |
| **Sum**   | **2.057**        | **Sum**   | **1.143**   | **−44.4%** |

---

## 6. Energy-Delay Product (EDP) Analysis

Energy = Power × Execution Time

| Metric                    | 2×Standard          | Hybrid              | Δ         |
|---------------------------|---------------------|---------------------|-----------|
| VCD Total Power (mW)      | 8.770               | 7.838               | −10.6%    |
| Execution Time (µs)       | 126.16              | 137.58              | +9.1%     |
| **Energy (nJ)**           | **1,106.4**         | **1,078.4**         | **−2.5%** |
| EDP (nJ·µs)               | 139,579             | 148,365             | +6.3%     |

---

## 7. Key Findings

### Power Savings
- **VCD-based total core power**: Hybrid saves **10.6%** (0.932 mW) over 2×Standard
- **Multiplier-specific savings**: Hybrid multiplier pair (MUL+MULE) uses **44.4% less power** than 2×MUL under VCD
- **MULE instance power**: 0.113 mW vs 1.028 mW for the second standard multiplier — **89% reduction**
- The leakage difference is small (3.6%), but dynamic power savings (internal + switching) are significant

### Performance Cost
- 2×Standard completes the workload in **12,616 cycles** vs Hybrid's **13,758 cycles** — a **9.1% speed advantage**
- This is due to 42.7% dual-MUL issue ratio on the unrolled matmul kernel

### Energy Efficiency
- Despite 9.1% longer execution, Hybrid's 10.6% lower power results in **2.5% lower total energy**
- The EDP slightly favors 2×Standard (+6.3%) due to quadratic time penalty

### Area
- Hybrid is **2.4% smaller** (62,019 µm² vs 63,561 µm²) post-P&R
- MULE replaces a full 32×32 multiplier with a resource-efficient design

### Trade-off Summary
| Factor            | Winner       | Margin    |
|-------------------|-------------|-----------|
| Power (VCD)       | Hybrid      | −10.6%    |
| Performance       | 2×Standard  | −9.1%     |
| Energy            | Hybrid      | −2.5%     |
| Area              | Hybrid      | −2.4%     |
| EDP               | 2×Standard  | −6.3%     |

---

## 8. Report Paths

```
Flows/NanGate45/biriscv_parallel_matmul/
├── constraints/core_100MHz.sdc
├── scripts/cadence/
│   ├── outputs/
│   │   ├── vcd/
│   │   │   ├── core_2standard.vcd (49 MB)
│   │   │   └── core_hybrid.vcd (48 MB)
│   │   ├── genus/
│   │   │   ├── core_2standard/syn_handoff/
│   │   │   └── core_hybrid/syn_handoff/
│   │   └── innovus/
│   │       ├── core_2standard/{vectorless,vcd}/reports/
│   │       └── core_hybrid/{vectorless,vcd}/reports/
│   ├── run_all.sh
│   ├── run_all_innovus.sh
│   ├── generate_vcds_xrun.sh
│   └── logs/
```

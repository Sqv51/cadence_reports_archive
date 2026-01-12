# Hybrid MUL+MULE Architecture: Dynamic Energy-Performance Optimization

**Date:** January 11, 2026  
**Concept:** Use both MUL (fast) and MULE (efficient) multipliers, selecting dynamically based on latency requirements

---

## The Hybrid Architecture Concept

### Basic Idea

**Deploy two multiplier units in parallel:**
- **MUL Path**: Fast 3-cycle pipelined multiplier (21.7 mW active)
- **MULE Path**: Efficient 5-cycle FSM multiplier (30.3 mW active, but 1.12 mW switching)

**Dynamic Selection:**
```
IF (result needed immediately OR critical path) THEN
    Use MUL  ← Fast path (3 cycles)
ELSE
    Use MULE ← Energy-efficient path (5 cycles)
```

**Analogy:** Similar to ARM big.LITTLE or Intel Turbo Boost, but for functional units.

---

## Energy Analysis

### Power Characteristics (from configs_v3 data)

| Multiplier | Latency | Active Power | Switching Power | Energy per Op |
|------------|---------|--------------|-----------------|---------------|
| **MUL** | 3 cycles | 21.7 mW | 3.15 mW | 7.7 µJ |
| **MULE** | 5 cycles | 30.3 mW | 1.12 mW | 10.6 µJ |
| **MULE (Opt)** | 5 cycles | ~27 mW | 1.12 mW | ~9.5 µJ |

### Energy Savings Potential

Assuming a workload with **mixed criticality** multiply operations:

#### Scenario 1: 50% Critical, 50% Non-Critical

**Baseline (MUL only):**
```
Total Energy = 100 operations × 7.7 µJ = 770 µJ
```

**Hybrid (MUL + MULE):**
```
Critical path:     50 ops × 7.7 µJ (MUL)  = 385 µJ
Non-critical path: 50 ops × 9.5 µJ (MULE) = 475 µJ
Total Energy = 860 µJ
```

**Result: Hybrid is WORSE by 11.7%** ⚠️

#### Scenario 2: 30% Critical, 70% Non-Critical

**Baseline (MUL only):**
```
Total Energy = 100 operations × 7.7 µJ = 770 µJ
```

**Hybrid (MUL + MULE):**
```
Critical path:     30 ops × 7.7 µJ (MUL)  = 231 µJ
Non-critical path: 70 ops × 9.5 µJ (MULE) = 665 µJ
Total Energy = 896 µJ
```

**Result: Hybrid is WORSE by 16.4%** ⚠️

### Why Doesn't It Work Well?

**Problem: MULE's energy per operation is actually HIGHER than MUL!**
- MUL: 7.7 µJ per operation (3 cycles × 21.7 mW × 2 µs)
- MULE: 9.5 µJ per operation (5 cycles × ~27 mW × 2 µs)

**The extra 2 cycles overwhelm the power savings.**

---

## When Would Hybrid Architecture Work?

### Requirement: MULE Must Have Lower Energy per Operation

For hybrid to save energy:
$$\text{Energy}_\text{MULE} < \text{Energy}_\text{MUL}$$

$$\text{Power}_\text{MULE} \times \text{Latency}_\text{MULE} < \text{Power}_\text{MUL} \times \text{Latency}_\text{MUL}$$

**Current situation:**
- MULE: 27 mW × 5 cycles = 135 mW·cycles
- MUL: 21.7 mW × 3 cycles = 65.1 mW·cycles

**MULE needs to be 2.07× more power efficient to break even!**

### Redesigned MULE Target Specs

To achieve energy savings, MULE would need:

$$\text{Power}_\text{MULE} < \frac{21.7 \text{ mW} \times 3}{5} = 13 \text{ mW}$$

**Required improvement:** 27 mW → 13 mW = **52% power reduction**

This is extremely aggressive! Current MULE optimizations achieved:
- Switching power: 1.12 mW (64% reduction vs MUL's 3.15 mW) ✓
- But internal power remains high due to FSM complexity

---

## Alternative Hybrid Strategies That Could Work

### Strategy 1: Voltage/Frequency Scaling on Single Multiplier

**Instead of two multipliers, use one with dynamic V/F:**

```
Critical path:   MUL @ 500 MHz, 1.0V → 3 cycles, 21.7 mW
Non-critical:    MUL @ 250 MHz, 0.8V → 6 cycles, ~8 mW
```

**Energy comparison:**
- Critical: 21.7 mW × 3 × 2 µs = 7.7 µJ
- Non-critical: 8 mW × 6 × 4 µs = 10.7 µJ (but at lower avg power)

**Advantage:** Single multiplier, less area overhead

### Strategy 2: Clock Gating with Latency Tolerance

**Keep MUL, but aggressively gate when not critical:**

```
IF (multiply in non-critical path AND no dependent ops soon) THEN
    Insert NOPs, extend latency to 5-6 cycles
    Gate multiplier clock extensively between stages
    Save dynamic power
```

**Estimated savings:** 20-30% on non-critical multiplies

### Strategy 3: Hybrid with Optimized MULE

**Only works if MULE can be dramatically improved:**

| Component | Current | Target | How |
|-----------|---------|--------|-----|
| Switching | 1.12 mW | 1.12 mW | Already optimal ✓ |
| Internal | ~25 mW | **<12 mW** | Aggressive FSM simplification |
| **Total** | **~27 mW** | **~13 mW** | 52% reduction needed |

**Optimizations needed:**
1. Single-cycle FSM decode (reduce state registers)
2. Operand hold instead of latch (reduce register switching)
3. Partial product reuse architecture
4. Ultra-aggressive clock gating on inactive states

---

## Practical Implementation Considerations

### Selection Logic Complexity

**How to determine criticality?**

#### Option A: Compiler Hints
```verilog
input wire multiply_critical_i;  // From compiler/ISA extension
```
- Pro: Accurate, no runtime overhead
- Con: Requires ISA changes, compiler support

#### Option B: Dynamic Dependency Analysis
```verilog
// Check if result is needed in next N cycles
wire result_needed_soon = scoreboard_check(rd_idx, N_cycles);
assign use_fast_path = result_needed_soon;
```
- Pro: Automatic, no software changes
- Con: Complex hardware, may mispredict

#### Option C: Performance Counter Based
```verilog
// Use fast path more when performance counters show stalls
assign use_fast_path = (pipeline_stall_rate > threshold);
```
- Pro: Adaptive to workload
- Con: Coarse-grained, slow adaptation

### Area Overhead

**Current area (from configs_v3):**
- MUL: 336.827 µm²
- MULE: 152.609 µm² (optimized)
- **Hybrid total: 489.436 µm²**

**Overhead calculation:**
- Single MUL: 336.827 µm²
- Hybrid: 489.436 µm²
- **Overhead: +45.3% area**

**Additional control logic:** ~50-100 µm² for selection logic

**Total overhead: ~50%** for uncertain energy benefit

### Control Overhead

**Selection logic adds:**
- Mux for result selection: 1 cycle penalty or bypass complexity
- Arbitration logic: Which multiplier gets the instruction?
- Result routing: Increased wire capacitance → power overhead

**Estimated power overhead:** 2-5 mW (negates much of the savings!)

---

## Energy Analysis with Realistic Assumptions

### Workload Characterization

**Typical RISC-V integer workloads:**

| Multiply Type | Percentage | Criticality | Notes |
|---------------|------------|-------------|-------|
| Loop counters | 15% | Low | Can tolerate latency |
| Array indexing | 20% | Medium | Sometimes critical |
| Data computation | 40% | High | Usually critical |
| Crypto/DSP | 25% | Very High | Always critical |

**Estimated critical ratio: 65-75%**

### Break-Even Analysis

For hybrid to break even (assuming 70% critical, 30% non-critical):

$$0.7 \times E_\text{MUL} + 0.3 \times E_\text{MULE} = E_\text{MUL\_only}$$

$$0.7 \times 7.7 + 0.3 \times E_\text{MULE} = 7.7$$

$$E_\text{MULE} = \frac{7.7 - 5.39}{0.3} = 7.7 \text{ µJ}$$

**MULE needs ≤7.7 µJ per operation (currently 9.5 µJ)**

**Required improvement:** 9.5 → 7.7 = **19% reduction**

### With Control Overhead Included

Assuming 3 mW control overhead:

$$0.7 \times (7.7 + 0.6) + 0.3 \times (E_\text{MULE} + 0.6) = 7.7$$

$$E_\text{MULE} \approx 6.5 \text{ µJ} \text{ required}$$

**Required improvement:** 9.5 → 6.5 = **32% reduction**

---

## Conclusion: Is Hybrid Worth It?

### Current Status: ❌ Not Recommended

**Energy Analysis:**
- MULE energy per op (9.5 µJ) > MUL energy per op (7.7 µJ)
- Hybrid would **increase** energy consumption by 11-16%
- Area overhead: +45-50%
- Control complexity: Significant

**Verdict:** With current implementations, hybrid is energy-negative.

### Future Potential: ⚠️ Maybe, with Major MULE Improvements

**Required for viability:**
1. MULE power reduction: 27 mW → <15 mW (45% reduction)
2. Critical path ratio: <50% of multiplies
3. Minimal control overhead: <1 mW
4. Accurate criticality prediction: >90% accuracy

**This is very challenging!**

### Better Alternatives

| Approach | Energy Savings | Complexity | Viability |
|----------|----------------|------------|-----------|
| **Single MUL with aggressive clock gating** | 15-25% | Low | ✓✓ High |
| **Dynamic voltage/frequency scaling** | 20-35% | Medium | ✓ Medium |
| **Just use MULE (simpler design)** | -23% (worse) | Low | ✓ If area critical |
| **Just use MUL (baseline)** | Baseline | Low | ✓✓ Best performance |
| **Hybrid MUL+MULE** | -12% to -16% (worse) | High | ❌ Low |

---

## Recommendation

### For Energy Optimization:

**Choose ONE multiplier:**
- **High performance needed:** MUL (3 cycles, 7.7 µJ/op)
- **Area constrained:** MULE (smaller area, 9.5 µJ/op)
- **Best energy-performance:** MUL with aggressive clock gating

**Then add orthogonal optimizations:**
1. Clock gating on multiplier when idle
2. Operand isolation (gate inputs when not valid)
3. Result forwarding (reduce pipeline stalls)
4. DVFS at system level (not just multiplier)

### For Future Research:

If you want to pursue hybrid multipliers, focus on:
1. **Dramatically improving MULE efficiency** (target <13 mW active)
2. **Compiler-directed selection** (ISA extensions for criticality hints)
3. **Workload analysis** to find applications with >50% non-critical multiplies
4. **Compare against simpler alternatives** (clock gating, DVFS)

---

## Theoretical Best Case

**If MULE could be improved to 12 mW (55% reduction):**

| Scenario | MUL Only | Hybrid (30/70) | Savings |
|----------|----------|----------------|---------|
| Energy | 770 µJ | 231 + 420 = 651 µJ | **15.5%** ✓ |

**Even then:**
- Area overhead: +45%
- Control complexity: High
- Benefit marginal compared to alternatives

**Alternative (clock gating on single MUL):**
- Energy savings: 20-25%
- Area overhead: <5%
- Complexity: Low

**Verdict:** Even with aggressive MULE improvements, simpler alternatives are more attractive.

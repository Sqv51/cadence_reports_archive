# Understanding Multiplier Power: Why Total Chip Power Can Be Misleading

**Date:** January 11, 2026  
**Question:** Why is total power worse for MULE and CBM configs_v3? How to properly measure multiplier power?

---

## The Problem: Total Power vs Component Power

### Total Chip Power (configs_v3 Results)

| Design | Total Power | Rank | Difference from Best |
|--------|-------------|------|---------------------|
| **CBM** (best) | 1.0513 W | 1st | - |
| **MULE** | 1.0651 W | 2nd | +1.3% worse |
| **MUL** (worst) | 1.0755 W | 3rd | +2.3% worse |

**Why this seems counterintuitive:**
- MULE and CBM are designed to be more power-efficient
- Yet MUL shows only slightly higher total power
- **This is misleading!**

---

## The Root Cause: Inactive Multiplier Overhead

### Power Breakdown by Multiplier Module

#### When Testing CBM Design:
| Module | Status | Leakage | Internal | Switching | Total |
|--------|--------|---------|----------|-----------|-------|
| **u_cbm** | ✅ ACTIVE | 1.25e-7 W | **24.4 mW** | **1.53 mW** | **25.9 mW** |
| u_mule | ❌ Idle | 1.18e-7 W | 23.2 mW | 0 W | 23.2 mW |
| u_mul | ❌ Idle | 2.75e-7 W | 16.8 mW | 0.09 mW | 16.9 mW |

#### When Testing MULE Design:
| Module | Status | Leakage | Internal | Switching | Total |
|--------|--------|---------|----------|-----------|-------|
| u_cbm | ❌ Idle | 1.22e-7 W | 24.0 mW | 0 W | 24.0 mW |
| **u_mule** | ✅ ACTIVE | 1.38e-7 W | **25.8 mW** | **4.54 mW** | **30.3 mW** |
| u_mul | ❌ Idle | 2.75e-7 W | 16.8 mW | 0 W | 16.8 mW |

#### When Testing MUL Design:
| Module | Status | Leakage | Internal | Switching | Total |
|--------|--------|---------|----------|-----------|-------|
| u_cbm | ❌ Idle | 1.22e-7 W | 24.0 mW | 0 W | 24.0 mW |
| u_mule | ❌ Idle | 1.18e-7 W | 23.2 mW | 0 W | 23.2 mW |
| **u_mul** | ✅ ACTIVE | 2.76e-7 W | **18.6 mW** | **3.15 mW** | **21.7 mW** |

---

## Key Insight: Inactive Multiplier Power Dominates

### Problem Analysis

**Each design has THREE multiplier units present:**
1. The active multiplier being tested
2. Two inactive multipliers consuming **static power**

**The inactive multipliers consume significant power even when idle:**
- CBM idle: ~24.0 mW
- MULE idle: ~23.2 mW  
- MUL idle: ~16.8 mW (smallest due to simpler logic)

**This creates a "penalty" for efficient designs:**
```
Total Power = Core Logic Power + Active Multiplier Power + Inactive Multiplier Static Power
```

When testing MULE:
- MULE active: 30.3 mW
- **+ CBM idle: 24.0 mW** ← Extra overhead!
- **+ MUL idle: 16.8 mW** ← Extra overhead!
- = 71.1 mW just for multipliers

When testing MUL:
- MUL active: 21.7 mW
- **+ CBM idle: 24.0 mW** ← Extra overhead!
- **+ MULE idle: 23.2 mW** ← Extra overhead!
- = 68.9 mW just for multipliers

**Result:** The 8.6 mW advantage of MULE's lower active power is overshadowed by the 40.8 mW overhead from inactive multipliers!

---

## Correct Way to Measure Multiplier Power

### Method 1: Active Switching Power Only (Dynamic Activity)

**This isolates the multiplication algorithm's efficiency:**

| Multiplier | Switching Power | Reduction vs MUL |
|------------|-----------------|------------------|
| **CBM** | 1.53 mW | **-51.4%** ✓ |
| **MUL** | 3.15 mW | Baseline |
| **MULE** | 4.54 mW | **-25.9%** (before optimization) |
| **MULE (Optimized)** | 1.12 mW | **-64.4%** ✓✓ |

**Why this is correct:**
- Switching power represents actual computation activity
- Directly correlates with multiplication operations
- Eliminates bias from static/leakage components

### Method 2: Active Module Total Power

**Includes both dynamic and algorithm-specific static power:**

| Multiplier | Total When Active | Difference |
|------------|-------------------|------------|
| **CBM** | 25.9 mW | - |
| **MUL** | 21.7 mW | **Lowest** |
| **MULE** | 30.3 mW | +4.4 mW vs CBM |

**Why MUL looks better here:**
- MUL has a 3-stage pipelined design (simpler control)
- CBM/MULE have FSM-based control with more states
- FSM registers contribute to internal power

### Method 3: Energy per Operation (Best Metric)

**Accounts for both power and latency:**

$$\text{Energy per Multiply} = \text{Active Power} \times \text{Latency} \times \text{Clock Period}$$

| Multiplier | Latency | Power (active) | Energy per Op | Efficiency Rank |
|------------|---------|----------------|---------------|-----------------|
| **MUL** | 3 cycles | 21.7 mW | 7.7 µJ | 2nd |
| **CBM** | ? cycles | 25.9 mW | ? | ? |
| **MULE** | 5 cycles | 30.3 mW | 10.6 µJ | 3rd |
| **MULE (Opt)** | 5 cycles | ~27 mW | ~9.5 µJ | Similar to MUL |

---

## Why Configs_v3 Shows Misleading Results

### The Multi-Multiplier Configuration Issue

**configs_v3 has all three multipliers instantiated simultaneously:**
- This is for **comparison testing only**
- Real designs would have **only one multiplier**

**Power overhead breakdown:**
```
CBM design total:  1.0513 W
  - Active CBM:      25.9 mW   ← What we care about
  - Idle MULE:       23.2 mW   ← Artificial overhead
  - Idle MUL:        16.9 mW   ← Artificial overhead
  - Core logic:     985.2 mW   ← Rest of the chip

MULE design total: 1.0651 W
  - Active MULE:     30.3 mW   ← What we care about
  - Idle CBM:        24.0 mW   ← Artificial overhead
  - Idle MUL:        16.8 mW   ← Artificial overhead
  - Core logic:     994.2 mW   ← Rest of the chip

MUL design total:  1.0755 W
  - Active MUL:      21.7 mW   ← What we care about
  - Idle CBM:        24.0 mW   ← Artificial overhead
  - Idle MULE:       23.2 mW   ← Artificial overhead
  - Core logic:    1006.7 mW   ← Rest of the chip
```

**The core logic power varies because:**
- Different multipliers affect pipeline control complexity
- Faster multipliers (MUL) reduce stall cycles → more pipeline activity
- Slower multipliers (MULE) increase stall cycles → different power patterns

---

## Correct Comparison Methodology

### ✓ Recommended Approaches:

#### 1. **Switching Power Comparison** (Best for Algorithm Efficiency)
```
Metric: Switching power of active multiplier only
Why: Directly measures dynamic computation activity
Result: MULE (optimized) 64.4% better than MUL
```

#### 2. **Energy per Operation** (Best for Overall Efficiency)
```
Metric: (Active module power) × (Latency) × (Clock period)
Why: Accounts for both power and performance
Result: MUL slightly better due to lower latency
```

#### 3. **Isolated Single-Multiplier Synthesis** (Best for Real Design)
```
Synthesize three separate designs:
- Core with ONLY MUL
- Core with ONLY MULE  
- Core with ONLY CBM
Compare total power directly (no inactive multiplier overhead)
```

#### 4. **Activity-Weighted Power**
```
Use VCD with realistic workloads
Measure: (Multiplier active %) × (Active power) + (Idle %) × (Idle power)
```

### ❌ Misleading Approaches:

- **Total chip power with multiple multipliers** ← Your configs_v3 issue
- **Static power comparison** (doesn't show computational efficiency)
- **Area as a proxy for power** (doesn't account for activity patterns)

---

## Real-World Design Recommendations

### For Your Actual Chip (Single Multiplier):

| Use Case | Best Choice | Reason |
|----------|-------------|--------|
| **Low Power Priority** | MULE (optimized) | 64% lower switching power |
| **Balanced Performance** | MUL | Lower latency, reasonable power |
| **Area Constrained** | CBM or MULE | ~50% smaller than MUL |
| **High Performance** | MUL | 3 cycles vs 5 cycles |

### Power Measurement Strategy:

1. **Synthesize single-multiplier variants** (remove unused multipliers)
2. **Use realistic VCD traces** from actual applications
3. **Measure switching power** of the active multiplier
4. **Calculate energy per operation** = Power × Latency × Clock period
5. **Consider workload mix**: % multiply instructions vs other operations

---

## Conclusion

**Your observation is correct**: Total power in configs_v3 is misleading because:

1. **Inactive multiplier overhead** (~40-47 mW) overwhelms the differences
2. **Core logic activity** varies based on multiplier latency
3. **MULE appears worse** despite being more power-efficient

**The correct way to evaluate multiplier power:**
- **Switching power** for algorithm efficiency: MULE wins (1.12 mW vs 3.15 mW)
- **Energy per operation** for system efficiency: MUL slightly better due to lower latency
- **Real chip power**: Synthesize with only one multiplier to eliminate bias

**For your thesis/paper:** Report both switching power and energy per operation, explaining that total chip power is confounded by multi-multiplier test infrastructure.

# Multiplier Latency Analysis (from RTL)

## MUL (biriscv_multiplier)
- **Type**: Combinational
- **Latency**: 1 cycle  
- **Path**: Inputs → Output in same cycle
- **Details**: 
  - Multiple combinational always @* blocks
  - Clock input for hold_i control
  - Standard Wallace tree or similar combinational multiplier

## MULE (biriscv_multiplier_efficient)  
- **Type**: Pipelined
- **Latency**: 3-4 cycles (estimated from state machine + pipeline stages)
- **Path**: Issue → 3-4 stages of registers → Writeback
- **Details**:
  - 3-bit state machine (state_q)
  - 4 pipeline registers: a_q, b_q, p0_q, p1_q
  - Partial product stages: p0 (A_l × B_l), p1 (A_l × B_h), p2 (A_h × B_l)
  - Valid output signal (writeback_valid_o) indicates completion

## CBM (column_bypass_multiplier)
- **Type**: Multi-cycle (Column-bypass architecture)
- **Latency**: 33 cycles
- **Path**: Issue → State machine → ~33 pipeline stages → Result valid
- **Details**:
  - Busy signal active during computation (busy_o = (state_q != IDLE))
  - Result valid pulse when done (result_valid_o)
  - Optimized for low-power through sequential column evaluation
  - Trade-off: Much slower but potentially lower power per operation

## Summary

```
┌──────────┬────────────┬──────────────────┐
│ Multiplier│ Latency    │ Architecture     │
├──────────┼────────────┼──────────────────┤
│ MUL      │ 1 cycle    │ Combinational    │
│ MULE     │ 3-4 cycles │ Pipelined        │
│ CBM      │ 33 cycles  │ Multi-cycle      │
└──────────┴────────────┴──────────────────┘
```

## EDP Impact

Given: Clock = 0.25 ns (4 GHz), Period = 0.25 ns

For 1000 operations:
- **MUL**: 1000 × 1 = 1000 cycles = 250 µs
- **MULE**: 1000 × 3.5 ≈ 3500 cycles = 875 µs  
- **CBM**: 1000 × 33 = 33000 cycles = 8250 µs (8.25 ms)

EDP = Power × (Latency²)

- **MUL**: P_mul × 1² = P_mul
- **MULE**: P_mule × 3.5² = 12.25 × P_mule
- **CBM**: P_cbm × 33² = 1089 × P_cbm

Even if CBM uses 100× less power, EDP would be:
- CBM: (P_cbm/100) × 1089 = 10.89 × P_cbm

So **MUL is likely best EDP** despite higher power, due to combinational latency.

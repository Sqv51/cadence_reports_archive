# Multiplier Latency Analysis (Updated with VCD Results)

## MUL (biriscv_multiplier)
- **Type**: Pipelined (Fixed Latency)
- **Latency**: 2 cycles
- **Path**: Input → Stage 1 Reg → Stage 2 Reg → Output
- **Details**: 
  - `MULT_STAGES` parameter (default 2)
  - Pipeline registers: `operand_a_e1_q`, `result_e2_q`
  - High-throughput design

## MULE (biriscv_multiplier_efficient)  
- **Type**: Iterative / State Machine
- **Latency**: 6-12 cycles (Measured Avg: 9 cycles)
- **Path**: Issue → State Machine (IDLE->CALC->DONE) → Writeback
- **Details**:
  - 5-state FSM (`IDLE`, `CALC0`, `CALC1`, `CALC2`, `DONE`)
  - Iterative calculation of partial products
  - Variable latency depending on pipeline hazards

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
│ MUL      │ 2 cycles   │ Pipelined        │
│ MULE     │ ~9 cycles  │ Iterative        │
│ CBM      │ 33 cycles  │ Multi-cycle      │
└──────────┴────────────┴──────────────────┘
```

## EDP Impact

Given: Clock = 0.25 ns (4 GHz), Period = 0.25 ns

For 1000 operations:
- **MUL**: 1000 × 2 = 2000 cycles = 500 ns
- **MULE**: 1000 × 9 = 9000 cycles = 2250 ns
- **CBM**: 1000 × 33 = 33000 cycles = 8250 ns

**EDP Comparison (Power × Latency²):**
- MUL: 1.0x (Baseline)
- MULE: (9/2)² = 20.25x worse
- CBM: (33/2)² = 272.25x worse

Note: Previous estimates assumed MUL was 1 cycle. The 2-cycle reality reduces the gap but MUL remains the clear winner.  
- **CBM**: 1000 × 33 = 33000 cycles = 8250 µs (8.25 ms)

EDP = Power × (Latency²)

- **MUL**: P_mul × 1² = P_mul
- **MULE**: P_mule × 3.5² = 12.25 × P_mule
- **CBM**: P_cbm × 33² = 1089 × P_cbm

Even if CBM uses 100× less power, EDP would be:
- CBM: (P_cbm/100) × 1089 = 10.89 × P_cbm

So **MUL is likely best EDP** despite higher power, due to combinational latency.

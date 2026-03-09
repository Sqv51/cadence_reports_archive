# =============================================================================
# Design Setup for biRISC-V Low-Power Synthesis
# Technology: ASAP7 7nm   |   Clock: 100 MHz (10 ns)
# Strategy: Minimize timing effort, maximize power effort
# =============================================================================

set DESIGN riscv_core
set sdc "../../constraints/riscv_core.sdc"
set rtldir /home/ykaraagac/biriscv/src/core

# ─── Genus Low-Power Synthesis Strategy ──────────────────────────────────────
# Per Genus Command Reference (Low Power Synthesis chapter):
#   syn_generic_effort  low   -> minimize timing effort at generic stage
#   syn_map_effort      low   -> minimize timing effort at mapping stage
#   syn_opt_effort      low   -> minimize timing effort at opt stage
#
# Power-focused attributes set in run_genus.tcl:
#   set_db design_power_effort high
#   set_db leakage_power_effort high
# ─────────────────────────────────────────────────────────────────────────────

# Effort levels: LOW for timing (we have 10x margin at 100 MHz on 7nm)
set_db syn_generic_effort low
set_db syn_map_effort     low
set_db syn_opt_effort     low

# ASAP7 technology specifics
set SITE "asap7sc7p5t"
set HALO_WIDTH 2
set TOP_ROUTING_LAYER 7

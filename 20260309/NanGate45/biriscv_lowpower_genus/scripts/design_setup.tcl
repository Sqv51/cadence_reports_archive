# =============================================================================
# Design Setup for biRISC-V Low-Power Synthesis
# Technology: NanGate45 (45nm)  |  Clock: 100 MHz (10 ns)
# Strategy: Minimize timing effort, maximize power effort
# =============================================================================

set DESIGN riscv_core
set sdc "../../constraints/riscv_core.sdc"
set rtldir /home/ykaraagac/biriscv/src/core

# ─── Genus Low-Power Synthesis Strategy ──────────────────────────────────────
# syn_generic/syn_map/syn_opt effort = LOW -> minimize timing effort
# Power-focused attributes set in run_genus.tcl:
#   set_db design_power_effort high
# ─────────────────────────────────────────────────────────────────────────────

# Effort levels: LOW for timing (100 MHz is very relaxed for 45nm)
set_db syn_generic_effort low
set_db syn_map_effort     low
set_db syn_opt_effort     low

# NanGate45 technology specifics
set SITE "FreePDK45_38x28_10R_NP_162NW_34O"
set HALO_WIDTH 5
set TOP_ROUTING_LAYER 10

# Design setup for biRISC-V on ASAP7 (7nm)

set DESIGN riscv_core
set sdc "constraints/riscv_core.sdc"
set rtldir /home/ziyx/cadence-bitirme/Testcases/biriscv/rtl

# Floorplan definitions (optional, for physical synthesis)
# if {[info exist ::env(PHY_SYNTH)] && $::env(PHY_SYNTH) == 1} {
#    set floorplan_def ../../def/${DESIGN}_fp_placed_macros.def
# } else {
#    set floorplan_def ../../def/${DESIGN}_fp.def
# }

#
# Effort level during optimization in syn_generic (generic synthesis) stage
# possible values are : high, medium or low
set_db syn_generic_effort medium

# Effort level during optimization in syn_map (technology mapping) stage
# possible values are : high, medium or low
set_db syn_map_effort medium

# Effort level during optimization in syn_opt (optimization) stage
# possible values are : high, medium, low, or extreme
set_db syn_opt_effort medium

#
# EXPERIMENTAL TNS optimization (Timing Slack optimization)
# set_db tns_opto true

#
# ASAP7 technology specifics
set SITE "asap7sc7p5t"
set HALO_WIDTH 2
set TOP_ROUTING_LAYER 7

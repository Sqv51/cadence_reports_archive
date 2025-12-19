################################################################################
#
# Init setup file
# Created by Genus(TM) Synthesis Solution on 12/18/2025 18:57:37
#
################################################################################
if { ![is_common_ui_mode] } { error "ERROR: This script requires common_ui to be active."}

read_netlist syn_handoff/riscv_core.v

init_design

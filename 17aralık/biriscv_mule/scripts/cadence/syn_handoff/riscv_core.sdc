# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.13-s073_1 on Mon Dec 08 15:09:20 UTC 2025

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design riscv_core

set_clock_gating_check -setup 0.0 
set_wire_load_mode "enclosed"

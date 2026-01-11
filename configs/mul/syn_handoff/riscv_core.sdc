# ####################################################################

#  Created by Genus(TM) Synthesis Solution 23.13-s073_1 on Sun Jan 11 14:18:18 UTC 2026

# ####################################################################

set sdc_version 2.0

set_units -capacitance 1000fF
set_units -time 1000ps

# Set the current design
current_design riscv_core

create_clock -name "core_clock" -period 2000.0 -waveform {0.0 1000.0} [get_ports clk_i]
set_clock_gating_check -setup 0.0 
set_wire_load_mode "enclosed"

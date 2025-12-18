#!/usr/bin/env tclsh
# Genus Synthesis Script for biRISC-V on ASAP7

source lib_setup.tcl
source design_setup.tcl

# set the output directories
set OUTPUTS_PATH  syn_output
set REPORTS_PATH  syn_rpt
set HANDOFF_PATH  syn_handoff

if {![file exists ${OUTPUTS_PATH}]} {
  file mkdir ${OUTPUTS_PATH}
}

if {![file exists ${REPORTS_PATH}]} {
  file mkdir ${REPORTS_PATH}
}

if {![file exists ${HANDOFF_PATH}]} {
  file mkdir ${HANDOFF_PATH}
}

# set threads for parallel synthesis
set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"

# Target library for synthesis
set list_lib "$libworst"
set link_library $list_lib
set target_library $list_lib

# set path
set_db hdl_flatten_complex_port true
set_db hdl_record_naming_style  %s_%s
set_db auto_ungroup none
set_db library $list_lib

#################################################
# Load Design and Initialize
#################################################

# Enable SystemVerilog parsing (use 'sv' instead of 'systemverilog')
set_db hdl_language sv

source rtl_list.tcl

# Build a single read_hdl command with all RTL files  
set read_args [list]
foreach rtl_file $rtl_all {
    lappend read_args $rtl_file
}

# Read all RTL files in single command with -sv flag
eval read_hdl -sv $read_args

elaborate $DESIGN
time_info Elaboration

read_sdc $sdc
init_design

check_design -unresolved

check_timing_intent

# reports the physical layout estimation report from lef and QRC tech file
report_ple > ${REPORTS_PATH}/ple.rpt 

# keep hierarchy during synthesis
set_db auto_ungroup none

#################################################
# Synthesis stages
#################################################

syn_generic
time_info GENERIC

# generate a summary for the current stage of synthesis
write_reports -directory ${REPORTS_PATH} -tag generic
write_db  ${OUTPUTS_PATH}/${DESIGN}_generic.db

syn_map
time_info MAPPED

# generate a summary for the current stage of synthesis
write_reports -directory ${REPORTS_PATH} -tag map
write_db  ${OUTPUTS_PATH}/${DESIGN}_map.db

syn_opt
time_info OPT 
write_db ${OUTPUTS_PATH}/${DESIGN}_opt.db

##############################################################################
# Power Analysis with VCD
##############################################################################
set VCD_FILE /home/ziyx/cadence-bitirme/sim_vcd_gen/waveform.vcd

if {[file exists $VCD_FILE]} {
    puts "INFO: Reading VCD activity data from $VCD_FILE"
    if {[catch {read_vcd -instance vcd_tb/u_dut -static $VCD_FILE 2>&1} err]} {
        puts "WARNING: VCD import encountered: $err"
        puts "Continuing with static probability for power estimation."
    } else {
        puts "SUCCESS: VCD loaded. Power report will be dynamic."
    }
} else {
    puts "WARNING: VCD file not found at $VCD_FILE. Using static activity."
}

##############################################################################
# Write reports
##############################################################################

# summarizes the information, warnings and errors
report_messages > ${REPORTS_PATH}/${DESIGN}_messages.rpt

# generate PPA reports (Power, Performance, Area)
report_gates > ${REPORTS_PATH}/${DESIGN}_gates.rpt
report_power > ${REPORTS_PATH}/${DESIGN}_power.rpt
report_area > ${REPORTS_PATH}/${DESIGN}_area.rpt
write_reports -directory ${REPORTS_PATH} -tag final 

# Write SDC and Verilog for handoff to P&R (Innovus)
write_sdc >${HANDOFF_PATH}/${DESIGN}.sdc
write_hdl > ${HANDOFF_PATH}/${DESIGN}.v

# For future P&R flow (uncomment when needed):
# write_design -innovus -base_name ${HANDOFF_PATH}/${DESIGN}

exit

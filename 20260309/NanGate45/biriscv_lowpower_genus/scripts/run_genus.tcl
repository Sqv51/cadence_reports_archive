#!/usr/bin/env tclsh
# =============================================================================
# Genus Low-Power Synthesis for biRISC-V 5-Multiplier Energy Comparison
# =============================================================================
#
# Strategy (per Genus Command Reference - Low Power Synthesis):
#   - syn_generic/syn_map/syn_opt effort = LOW  (timing is easy at 100 MHz)
#   - design_power_effort = HIGH  (maximize power optimization)
#   - Power-driven mapping and optimization enabled
#   - VCD-based switching activity for accurate power analysis
#
# Technology: NanGate45 (45nm)  |  Clock: 100 MHz (10 ns period)
# =============================================================================

source lib_setup.tcl
source design_setup.tcl

# Output directories
set OUTPUTS_PATH  syn_output
set REPORTS_PATH  syn_rpt
set HANDOFF_PATH  syn_handoff

foreach dir [list $OUTPUTS_PATH $REPORTS_PATH $HANDOFF_PATH] {
    if {![file exists $dir]} { file mkdir $dir }
}

# Parallel threads
set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"

# Target library
set list_lib "$libworst"
set link_library $list_lib
set target_library $list_lib

set_db library $list_lib

# =============================================================================
# LOW-POWER GENUS SETTINGS (Genus Command Reference)
# =============================================================================

# ── Power Effort ─────────────────────────────────────────────────────────────
# set_db design_power_effort: controls how aggressively Genus optimizes power
#   high = Genus spends more time finding lower-power implementations
set_db design_power_effort high

# ── Clock Gating ─────────────────────────────────────────────────────────────
# Disabled: clock gating creates a massive clock tree (27K buffers) that
# causes Innovus CTS DRV fixing to hang for 30+ hours.
# Power comparison between multipliers remains valid without CG.
# set_db lp_insert_clock_gating true

# ── HDL Settings ─────────────────────────────────────────────────────────────
set_db hdl_flatten_complex_port true
set_db hdl_record_naming_style  %s_%s
set_db auto_ungroup none
set_db hdl_language sv

# =============================================================================
# Load Design
# =============================================================================
source rtl_list.tcl

set read_args [list]
foreach rtl_file $rtl_all {
    lappend read_args $rtl_file
}
eval read_hdl -sv $read_args

elaborate $DESIGN
time_info Elaboration

# Read constraints (100 MHz relaxed clock)
read_sdc $sdc
init_design

check_design -unresolved
check_timing_intent

# Physical layout estimation
report_ple > ${REPORTS_PATH}/ple.rpt

# Keep hierarchy (important for per-module power reporting)
set_db auto_ungroup none

# =============================================================================
# Synthesis (Low timing effort, high power effort)
# =============================================================================

puts "================================================================"
puts "Stage 1: syn_generic (effort=low, power_effort=high)"
puts "================================================================"
syn_generic
time_info GENERIC
write_reports -directory ${REPORTS_PATH} -tag generic
write_db ${OUTPUTS_PATH}/${DESIGN}_generic.db

puts "================================================================"
puts "Stage 2: syn_map (effort=low, power_effort=high)"
puts "================================================================"
syn_map
time_info MAPPED
write_reports -directory ${REPORTS_PATH} -tag map
write_db ${OUTPUTS_PATH}/${DESIGN}_map.db

puts "================================================================"
puts "Stage 3: syn_opt (effort=low, power_effort=high)"
puts "================================================================"
syn_opt
time_info OPT
write_db ${OUTPUTS_PATH}/${DESIGN}_opt.db

# =============================================================================
# Reports: Vectorless Power (baseline)
# =============================================================================
report_messages > ${REPORTS_PATH}/${DESIGN}_messages.rpt
report_gates    > ${REPORTS_PATH}/${DESIGN}_gates.rpt
report_power    > ${REPORTS_PATH}/${DESIGN}_power_vectorless.rpt
report_area     > ${REPORTS_PATH}/${DESIGN}_area.rpt
report_timing   > ${REPORTS_PATH}/${DESIGN}_timing.rpt
report_qor      > ${REPORTS_PATH}/${DESIGN}_qor.rpt
write_reports -directory ${REPORTS_PATH} -tag final

# ── Per-module area/power reports (all 5 multipliers) ────────────────────────
foreach mul {u_mul u_mule u_muls u_cbm u_mulp} {
    report_area  -hinst $mul > ${REPORTS_PATH}/area_${mul}.rpt
    report_power -inst  $mul > ${REPORTS_PATH}/power_vectorless_${mul}.rpt
}

# =============================================================================
# VCD-Based Power Analysis
# =============================================================================
puts "================================================================"
puts "Reading VCD file for switching-activity power analysis ..."
puts "================================================================"

# VCD file path (reuse RTL-level VCD from ASAP7 flow — technology-independent)
set vcd_dir "../../vcd_gen"
set vcd_file "${vcd_dir}/mul5_power.vcd"

if {[file exists $vcd_file]} {
    # Read VCD - map testbench hierarchy to synthesized design
    read_vcd $vcd_file -vcd_scope tb_mul5/u_dut

    # Full-design VCD power
    report_power > ${REPORTS_PATH}/${DESIGN}_power_vcd.rpt
    report_power -by_hierarchy > ${REPORTS_PATH}/power_vcd_hierarchy.rpt

    # Per-multiplier VCD power reports
    foreach mul {u_mul u_mule u_muls u_cbm u_mulp} {
        report_power -inst $mul > ${REPORTS_PATH}/power_vcd_${mul}.rpt
    }

    puts "VCD power reports written successfully."
} else {
    puts "WARNING: VCD file $vcd_file not found"
    puts "  Run vcd_gen/generate_vcd_xcelium.sh first, then re-run this script"
}

# =============================================================================
# Write Handoff for Innovus
# =============================================================================
write_sdc > ${HANDOFF_PATH}/${DESIGN}.sdc
write_hdl > ${HANDOFF_PATH}/${DESIGN}.v

puts "================================================================"
puts " LOW-POWER SYNTHESIS COMPLETE"
puts " Technology: NanGate45 (45nm)  |  Clock: 100 MHz (10 ns)"
puts " Strategy: timing_effort=low, power_effort=high"
puts " Reports: ${REPORTS_PATH}/"
puts " Handoff: ${HANDOFF_PATH}/"
puts "================================================================"

exit

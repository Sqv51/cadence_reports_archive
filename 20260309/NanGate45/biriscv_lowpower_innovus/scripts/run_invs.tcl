#!/usr/bin/env tclsh
# =============================================================================
# Innovus P&R with Power-Focused Optimization for biRISC-V
# =============================================================================
#
# Strategy:
#   - setOptMode -powerEffort high       (maximize power reduction)
#   - leakageToDynamicRatio 0.5          (balance leakage vs dynamic)
#   - Power-driven placement (activity + clock)
#   - VCD-based power analysis post-route
#   - Per-multiplier power reporting
#
# Technology: NanGate45 (45nm)  |  Clock: 100 MHz (10 ns)
# Verified against Innovus DDI 25.1 help
# =============================================================================

source lib_setup.tcl
source design_setup.tcl

set handoff_dir  "./syn_handoff"
set netlist ${handoff_dir}/${DESIGN}.v
set sdc ${handoff_dir}/${DESIGN}.sdc

source mmmc_setup.tcl

setMultiCpuUsage -localCpu 16
set util 0.3

set rptDir summaryReport/
set encDir enc/

if {![file exists ${rptDir}/]} { exec mkdir -p $rptDir }
if {![file exists ${encDir}/]} { exec mkdir -p $encDir }

# =============================================================================
# Initialize Design
# =============================================================================
set init_pwr_net VDD
set init_gnd_net VSS
set init_verilog "$netlist"
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell "$DESIGN"
set init_lef_file "$lefs"

# MCMM setup
init_design -setup {WC_VIEW} -hold {BC_VIEW}
set_power_analysis_mode -leakage_power_view WC_VIEW -dynamic_power_view WC_VIEW

set_interactive_constraint_modes {CON}
setAnalysisMode -reset
setAnalysisMode -analysisType onChipVariation -cppr both

# Power connections
clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override

# =============================================================================
# POWER-FOCUSED OPTIMIZATION SETTINGS
# =============================================================================
setOptMode -powerEffort high -leakageToDynamicRatio 0.5

# Enable power-driven placement
setPlaceMode -place_global_activity_power_driven true
setPlaceMode -place_global_clock_power_driven true

setGenerateViaMode -auto true
generateVias

# Path groups for timing
createBasicPathGroups -expanded

# =============================================================================
# Post-Synth Report Header
# =============================================================================
echo "Physical Design Stage, Core Area (um^2), Standard Cell Area (um^2), Macro Area (um^2), Total Power (mW), Wirelength(um), WS(ns), TNS(ns), Congestion(H), Congestion(V)" > ${DESIGN}_DETAILS.rpt

# Inline extract_metrics proc — simplified to avoid PODv2 API errors
proc extract_metrics {stage} {
    set core_area "N/A"
    set std_sum "N/A"
    set macro_sum "N/A"
    set pwr "N/A"
    set ws "N/A"
    set tns "N/A"
    set wl "N/A"

    catch { set core_area [lindex [report_design_area] end] }
    catch {
        report_power -outfile .tmp_power.rpt
        set fp [open .tmp_power.rpt r]
        set txt [read $fp]
        close $fp
        regexp {Total\s+[\d.e+-]+\s+[\d.e+-]+\s+[\d.e+-]+\s+([\d.e+-]+)} $txt -> pwr
        file delete .tmp_power.rpt
    }

    return "$stage, $core_area, $std_sum, $macro_sum, $pwr, $wl, $ws, $tns, N/A, N/A"
}

set rpt_synth [extract_metrics "postSynth"]
echo "$rpt_synth" >> ${DESIGN}_DETAILS.rpt

# =============================================================================
# Floorplan (no macros, auto floorplan)
# =============================================================================
floorPlan -site $SITE -r 1.0 $util 5.0 5.0 5.0 5.0

# =============================================================================
# Power Grid (NanGate45 PDN)
# =============================================================================
# Follow pins on metal1/metal2
sroute -connect { corePin } -layerChangeRange { metal1 metal2 } \
       -blockPinTarget { nearestTarget } -corePinTarget { firstAfterRowEnd } \
       -allowJogging 1 -crossoverViaLayerRange { metal1 metal2 } \
       -nets { VDD VSS } -verbose

# metal4: vertical stripes (from NanGate45 pdn_config.tcl)
addStripe -nets {VSS VDD} -layer metal4 -direction vertical \
    -width 0.84 -spacing 0.56 -set_to_set_distance 20.16 \
    -start_offset 2

# metal7: horizontal stripes
addStripe -nets {VSS VDD} -layer metal7 -direction horizontal \
    -width 2.4 -spacing 1.6 -set_to_set_distance 40 \
    -start_offset 2

# metal10: vertical stripes (top power layer)
addStripe -nets {VSS VDD} -layer metal10 -direction vertical \
    -width 3.20 -spacing 1.6 -set_to_set_distance 32 \
    -start_offset 2

saveDesign ${encDir}/${DESIGN}_floorplan.enc

set rpt_fp [extract_metrics "floorplan"]
echo "$rpt_fp" >> ${DESIGN}_DETAILS.rpt

# =============================================================================
# Placement (power-driven)
# =============================================================================
setPlaceMode -place_detail_legalization_inst_gap 1
setFillerMode -fitGap true
setDesignMode -topRoutingLayer $TOP_ROUTING_LAYER
setDesignMode -bottomRoutingLayer 2

place_opt_design -out_dir $rptDir -prefix place
saveDesign $encDir/${DESIGN}_placed.enc

set rpt_place [extract_metrics "preCTS"]
echo "$rpt_place" >> ${DESIGN}_DETAILS.rpt

# Per-multiplier area after placement
foreach mul {u_mul u_mule u_muls u_cbm u_mulp} {
    report_area -hierarchical_instance $mul > ${rptDir}/area_placed_${mul}.rpt
}

# =============================================================================
# CTS (Clock Tree Synthesis)
# =============================================================================
set_ccopt_property post_conditioning_enable_routing_eco 1
set_ccopt_property -cts_def_lock_clock_sinks_after_routing true
setOptMode -unfixClkInstForOpt false

create_ccopt_clock_tree_spec
clock_opt_design

set_interactive_constraint_modes [all_constraint_modes -active]
set_propagated_clock [all_clocks]
set_clock_propagation propagated

saveDesign $encDir/${DESIGN}_cts.enc

set rpt_cts [extract_metrics "postCTS"]
echo "$rpt_cts" >> ${DESIGN}_DETAILS.rpt

# =============================================================================
# Routing (timing + SI driven)
# =============================================================================
setNanoRouteMode -drouteVerboseViolationSummary 1
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeUseAutoVia true

# NanGate45-specific routing settings
setNanoRouteMode -routeWithViaInPin "1:1"
setNanoRouteMode -routeWithViaOnlyForStandardCellPin "1:1"
setNanoRouteMode -drouteOnGridOnly "via 1:1"
setNanoRouteMode -drouteAutoStop false
setNanoRouteMode -drouteExpAdvancedMarFix true
setNanoRouteMode -routeExpAdvancedTechnology true
setNanoRouteMode -grouteExpWithTimingDriven false

routeDesign
saveDesign ${encDir}/${DESIGN}_route.enc

# DRC/LVS checks
verify_connectivity -error 0 -geom_connect -no_antenna
verify_drc -limit 0

set rpt_route [extract_metrics "postRoute"]
echo "$rpt_route" >> ${DESIGN}_DETAILS.rpt

defOut -netlist -floorplan -routing ${DESIGN}_route.def

# =============================================================================
# Post-Route Optimization (power-focused)
# =============================================================================
optDesign -postRoute

set rpt_opt [extract_metrics "postRouteOpt"]
echo "$rpt_opt" >> ${DESIGN}_DETAILS.rpt

# =============================================================================
# Final Power Reports (per multiplier)
# =============================================================================
puts "================================================================"
puts "Generating post-route power reports..."
puts "================================================================"

report_power -outfile ${rptDir}/${DESIGN}_power_final.rpt
report_power -hierarchy all -outfile ${rptDir}/${DESIGN}_power_hierarchy.rpt

foreach mul {u_mul u_mule u_muls u_cbm u_mulp} {
    report_power -instances $mul -outfile ${rptDir}/power_postroute_${mul}.rpt
    report_area  -hierarchical_instance $mul > ${rptDir}/area_postroute_${mul}.rpt
}

# =============================================================================
# VCD-Based Post-Route Power (if VCD available)
# =============================================================================
set vcd_file "../../vcd_gen/mul5_power.vcd"
if {[file exists $vcd_file]} {
    puts "Reading VCD for post-route power analysis..."
    read_activity_file -format VCD -scope tb_mul5/u_dut $vcd_file

    report_power -outfile ${rptDir}/${DESIGN}_power_vcd_postroute.rpt
    report_power -hierarchy all -outfile ${rptDir}/power_vcd_postroute_hierarchy.rpt

    foreach mul {u_mul u_mule u_muls u_cbm u_mulp} {
        report_power -instances $mul -outfile ${rptDir}/power_vcd_postroute_${mul}.rpt
    }
    puts "VCD post-route power reports written."
} else {
    puts "WARNING: VCD file not found for post-route power analysis"
}

# =============================================================================
# Save & Export
# =============================================================================
summaryReport -noHtml -outdir ${rptDir}
saveDesign ${encDir}/${DESIGN}.enc
defOut -netlist -floorplan -routing ${DESIGN}.def

# Write post-route netlist for signoff power
saveNetlist ${DESIGN}_postroute.v

puts "================================================================"
puts " INNOVUS POWER-FOCUSED P&R COMPLETE"
puts " Technology: NanGate45 (45nm)  |  Clock: 100 MHz (10 ns)"
puts " Reports:  ${rptDir}/"
puts " Design:   ${encDir}/${DESIGN}.enc"
puts " Summary:  ${DESIGN}_DETAILS.rpt"
puts "================================================================"

exit

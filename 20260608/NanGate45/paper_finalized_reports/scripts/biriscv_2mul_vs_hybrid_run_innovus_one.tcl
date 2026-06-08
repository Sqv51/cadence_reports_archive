if {![info exists ::env(DESIGN)] || ![info exists ::env(TOP_MODULE)] || ![info exists ::env(SDC_FILE)] || ![info exists ::env(ACTIVITY_MODE)]} {
    puts "ERROR: Missing one or more required env vars: DESIGN TOP_MODULE SDC_FILE ACTIVITY_MODE"
    exit 2
}

set DESIGN        $::env(DESIGN)
set TOP_MODULE    $::env(TOP_MODULE)
set sdc           $::env(SDC_FILE)
set ACTIVITY_MODE $::env(ACTIVITY_MODE)
set VCD_FILE      ""
set VCD_SCOPE     ""
set REPORT_INST_A ""
set REPORT_INST_B ""

if {[info exists ::env(VCD_FILE)]}     { set VCD_FILE $::env(VCD_FILE) }
if {[info exists ::env(VCD_SCOPE)]}    { set VCD_SCOPE $::env(VCD_SCOPE) }
if {[info exists ::env(REPORT_INST_A)]} { set REPORT_INST_A $::env(REPORT_INST_A) }
if {[info exists ::env(REPORT_INST_B)]} { set REPORT_INST_B $::env(REPORT_INST_B) }

source lib_setup.tcl
source mmmc_setup.tcl

set handoff_dir "outputs/genus/${DESIGN}/syn_handoff"
set netlist     "${handoff_dir}/${DESIGN}.v"

set rptDir      "outputs/innovus/${DESIGN}/${ACTIVITY_MODE}/reports"
set dbDir       "outputs/innovus/${DESIGN}/${ACTIVITY_MODE}/enc"

foreach d [list $rptDir $dbDir] {
    if {![file exists $d]} { exec mkdir -p $d }
}

setMultiCpuUsage -localCpu 16
set init_pwr_net VDD
set init_gnd_net VSS
set init_verilog $netlist
set init_design_netlisttype "Verilog"
set init_design_settop 1
set init_top_cell $TOP_MODULE
set init_lef_file "$lefs"

init_design -setup {WC_VIEW} -hold {BC_VIEW}
set_power_analysis_mode -leakage_power_view WC_VIEW -dynamic_power_view WC_VIEW

set_interactive_constraint_modes {CON}
setAnalysisMode -reset
setAnalysisMode -analysisType onChipVariation -cppr both

clearGlobalNets
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
globalNetConnect VDD -type tiehi -inst * -override
globalNetConnect VSS -type tielo -inst * -override

createBasicPathGroups -expanded

floorPlan -site $SITE -r 1.0 0.70 10 10 10 10
assignIoPins -align -autoBusGroup
setDesignMode -topRoutingLayer $TOP_ROUTING_LAYER
setDesignMode -bottomRoutingLayer 2

place_opt_design -out_dir $rptDir -prefix place

set_ccopt_property post_conditioning_enable_routing_eco 1
set_ccopt_property -cts_def_lock_clock_sinks_after_routing true
setOptMode -unfixClkInstForOpt false
create_ccopt_clock_tree_spec
clock_opt_design

set_propagated_clock [all_clocks]
set_clock_propagation propagated

setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeUseAutoVia true
setNanoRouteMode -routeWithViaInPin "1:1"
setNanoRouteMode -routeWithViaOnlyForStandardCellPin "1:1"
routeDesign
optDesign -postRoute

extractRC
write_sdf ${dbDir}/${DESIGN}.sdf

if {$ACTIVITY_MODE == "vcd"} {
    if {[file exists $VCD_FILE]} {
        if {[string length $VCD_SCOPE] > 0} {
            read_activity_file -format VCD $VCD_FILE -scope $VCD_SCOPE
        } else {
            read_activity_file -format VCD $VCD_FILE
        }
    } else {
        puts "WARN: VCD mode requested but file not found: $VCD_FILE"
    }
}

summaryReport -noHtml -outfile ${rptDir}/post_route.sum
redirect ${rptDir}/power_total.rpt { report_power }
redirect ${rptDir}/power_hierarchy.rpt { report_power -hierarchy all }

if {[string length $REPORT_INST_A] > 0} {
    if {[catch {redirect ${rptDir}/power_inst_a.rpt {report_power -instance $REPORT_INST_A}}]} {
        catch {redirect ${rptDir}/power_inst_a.rpt {report_power -inst $REPORT_INST_A}}
    }
}

if {[string length $REPORT_INST_B] > 0} {
    if {[catch {redirect ${rptDir}/power_inst_b.rpt {report_power -instance $REPORT_INST_B}}]} {
        catch {redirect ${rptDir}/power_inst_b.rpt {report_power -inst $REPORT_INST_B}}
    }
}

saveDesign ${dbDir}/${DESIGN}.enc
defOut -netlist -floorplan -routing ${dbDir}/${DESIGN}.def

exit

if {![info exists ::env(DESIGN)] || ![info exists ::env(TOP_MODULE)] || ![info exists ::env(SDC_FILE)] || ![info exists ::env(ACTIVITY_MODE)]} {
    puts "ERROR: Missing one or more required env vars: DESIGN TOP_MODULE SDC_FILE ACTIVITY_MODE"
    exit 2
}

set DESIGN        $::env(DESIGN)
set TOP_MODULE    $::env(TOP_MODULE)
set sdc           $::env(SDC_FILE)
set ACTIVITY_MODE $::env(ACTIVITY_MODE)
set FLOW_MODE     "full"
set LOW_EFFORT    0
set VCD_FILE      ""
set VCD_SCOPE     ""
set BASE_ENC      ""
set REPORT_INST_A ""
set REPORT_INST_B ""

if {[info exists ::env(FLOW_MODE)]}    { set FLOW_MODE [string tolower $::env(FLOW_MODE)] }
if {[info exists ::env(LOW_EFFORT)]}   { set LOW_EFFORT $::env(LOW_EFFORT) }
if {[info exists ::env(VCD_FILE)]}     { set VCD_FILE $::env(VCD_FILE) }
if {[info exists ::env(VCD_SCOPE)]}    { set VCD_SCOPE $::env(VCD_SCOPE) }
if {[info exists ::env(BASE_ENC)]}     { set BASE_ENC $::env(BASE_ENC) }
if {[info exists ::env(REPORT_INST_A)]} { set REPORT_INST_A $::env(REPORT_INST_A) }
if {[info exists ::env(REPORT_INST_B)]} { set REPORT_INST_B $::env(REPORT_INST_B) }

if {$FLOW_MODE ne "full" && $FLOW_MODE ne "power_only"} {
    puts "ERROR: Unsupported FLOW_MODE='$FLOW_MODE' (expected 'full' or 'power_only')"
    exit 2
}

source lib_setup.tcl
source mmmc_setup.tcl

set handoff_dir "outputs/genus/${DESIGN}/syn_handoff"
set netlist     "${handoff_dir}/${DESIGN}.v"
set implDir     "outputs/innovus/${DESIGN}/implemented"
set implEnc     "${implDir}/${DESIGN}.enc"

set rptDir      "outputs/innovus/${DESIGN}/${ACTIVITY_MODE}/reports"
set dbDir       "outputs/innovus/${DESIGN}/${ACTIVITY_MODE}/enc"

foreach d [list $rptDir $dbDir $implDir] {
    if {![file exists $d]} { exec mkdir -p $d }
}

puts "================================================================="
puts "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] Innovus run"
puts "  DESIGN       : $DESIGN"
puts "  TOP_MODULE   : $TOP_MODULE"
puts "  SDC          : $sdc"
puts "  ACTIVITY_MODE: $ACTIVITY_MODE"
puts "  FLOW_MODE    : $FLOW_MODE"
puts "  LOW_EFFORT   : $LOW_EFFORT"
if {[string length $VCD_FILE] > 0} {
    puts "  VCD_FILE     : $VCD_FILE"
}
if {[string length $VCD_SCOPE] > 0} {
    puts "  VCD_SCOPE    : $VCD_SCOPE"
}
puts "================================================================="

if {$LOW_EFFORT == 1} {
    setMultiCpuUsage -localCpu 8
} else {
    setMultiCpuUsage -localCpu 16
}
if {$FLOW_MODE eq "full"} {
    puts "INFO: Initializing design from Genus handoff netlist"
    set init_pwr_net VDD
    set init_gnd_net VSS
    set init_verilog $netlist
    set init_design_netlisttype "Verilog"
    set init_design_settop 1
    set init_top_cell $TOP_MODULE
    set init_lef_file "$lefs"

    init_design -setup {WC_VIEW} -hold {BC_VIEW}

    set_interactive_constraint_modes {CON}
    setAnalysisMode -reset
    setAnalysisMode -analysisType onChipVariation -cppr both

    clearGlobalNets
    globalNetConnect VDD -type pgpin -pin VDD -inst * -override
    globalNetConnect VSS -type pgpin -pin VSS -inst * -override
    globalNetConnect VDD -type tiehi -inst * -override
    globalNetConnect VSS -type tielo -inst * -override

    createBasicPathGroups -expanded

    puts "INFO: Starting floorplan/place"
    floorPlan -site $SITE -r 1.0 0.70 10 10 10 10
    assignIoPins -align -autoBusGroup
    setDesignMode -topRoutingLayer $TOP_ROUTING_LAYER
    setDesignMode -bottomRoutingLayer 2
    place_opt_design -out_dir $rptDir -prefix place

    puts "INFO: Starting clock optimization"
    set_ccopt_property post_conditioning_enable_routing_eco 1
    set_ccopt_property -cts_def_lock_clock_sinks_after_routing true
    setOptMode -unfixClkInstForOpt false
    clock_opt_design

    puts "INFO: Starting routing/post-route optimization"
    set_propagated_clock [all_clocks]
    set_clock_propagation propagated

    if {$LOW_EFFORT == 1} {
        setNanoRouteMode -routeWithSiDriven false
        setNanoRouteMode -routeWithTimingDriven false
    } else {
        setNanoRouteMode -routeWithSiDriven true
        setNanoRouteMode -routeWithTimingDriven true
    }
    setNanoRouteMode -routeUseAutoVia true
    setNanoRouteMode -routeWithViaInPin "1:1"
    setNanoRouteMode -routeWithViaOnlyForStandardCellPin "1:1"
    routeDesign
    if {$LOW_EFFORT != 1} {
        optDesign -postRoute
    }

    puts "INFO: Extracting post-route parasitics and writing SDF"
    extractRC
    write_sdf ${dbDir}/${DESIGN}.sdf

    puts "INFO: Saving implemented design to $implEnc"
    saveDesign $implEnc
    defOut -netlist -floorplan -routing ${dbDir}/${DESIGN}.def
} else {
    if {[string length $BASE_ENC] == 0} {
        set BASE_ENC $implEnc
    }
    if {[file exists "${BASE_ENC}.dat"]} {
        set BASE_ENC "${BASE_ENC}.dat"
    }
    if {![file exists $BASE_ENC]} {
        puts "ERROR: FLOW_MODE=power_only but BASE_ENC not found: $BASE_ENC"
        exit 3
    }
    puts "INFO: Restoring implemented design from $BASE_ENC"
    restoreDesign $BASE_ENC
}

set_power_analysis_mode -leakage_power_view WC_VIEW -dynamic_power_view WC_VIEW

if {[string length $VCD_FILE] > 0} {
    if {[file exists $VCD_FILE]} {
        puts "INFO: Reading VCD activity"
        if {[string length $VCD_SCOPE] > 0} {
            read_activity_file -format VCD $VCD_FILE -scope $VCD_SCOPE
        } else {
            read_activity_file -format VCD $VCD_FILE
        }
    } else {
        puts "WARN: VCD mode requested but file not found: $VCD_FILE"
    }
} else {
    puts "INFO: No VCD file supplied; using current/default activity assumptions"
}

puts "INFO: Generating reports in $rptDir"
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

puts "INFO: Saving activity-specific design snapshot to ${dbDir}/${DESIGN}.enc"
saveDesign ${dbDir}/${DESIGN}.enc

puts "INFO: Innovus power run completed for $DESIGN / $ACTIVITY_MODE / $FLOW_MODE"

exit

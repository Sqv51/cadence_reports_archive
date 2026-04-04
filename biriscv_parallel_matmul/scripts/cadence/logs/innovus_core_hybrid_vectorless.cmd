#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Tue Mar 31 09:48:14 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v25.12-s079_1 (64bit) 11/18/2025 12:56 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: NanoRoute 25.12-s079_1 NR251112-0044/25_12-UB (database version 18.20.680) {superthreading v2.20}
#@(#)CDS: AAE 25.12-s028 (64bit) 11/18/2025 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: CTE 25.12-s024_1 () Nov 12 2025 02:41:04 ( )
#@(#)CDS: SYNTECH 25.12-s006_1 () Oct 30 2025 11:18:17 ( )
#@(#)CDS: CPE v25.12-s020
#@(#)CDS: IQuantus/TQuantus 24.1.0-s365 (64bit) Mon Oct 13 00:44:28 PDT 2025 (Linux 4.18.0-305.el8.x86_64)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
setDesignMode -process 45
create_library_set -name WC_LIB -timing $libworst
create_library_set -name BC_LIB -timing $libbest
create_rc_corner -name Cmax -qx_tech_file $qrc_max
create_rc_corner -name Cmin -qx_tech_file $qrc_min
create_delay_corner -name WC -library_set WC_LIB -rc_corner Cmax
create_delay_corner -name BC -library_set BC_LIB -rc_corner Cmin
create_constraint_mode -name CON -sdc_file $sdc
create_analysis_view -name WC_VIEW -delay_corner WC -constraint_mode CON
create_analysis_view -name BC_VIEW -delay_corner BC -constraint_mode CON
setMultiCpuUsage -localCpu 16
set init_pwr_net VDD
set init_gnd_net VSS
set init_verilog outputs/genus/core_hybrid/syn_handoff/core_hybrid.v
set init_design_netlisttype Verilog
set init_design_settop 1
set init_top_cell riscv_core
set init_lef_file {../../../../../Enablements/NanGate45/lef/NangateOpenCellLibrary.tech.lef ../../../../../Enablements/NanGate45/lef/NangateOpenCellLibrary.macro.mod.lef}
init_design -setup WC_VIEW -hold BC_VIEW
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
floorPlan -site FreePDK45_38x28_10R_NP_162NW_34O -r 1.0 0.70 10 10 10 10
setDesignMode -topRoutingLayer 10
setDesignMode -bottomRoutingLayer 2
place_opt_design -out_dir outputs/innovus/core_hybrid/vectorless/reports -prefix place
set_ccopt_property post_conditioning_enable_routing_eco 1
set_ccopt_property -cts_def_lock_clock_sinks_after_routing true
setOptMode -unfixClkInstForOpt false
create_ccopt_clock_tree_spec
clock_opt_design
set_propagated_clock [all_clocks]
setNanoRouteMode -routeWithSiDriven true
setNanoRouteMode -routeWithTimingDriven true
setNanoRouteMode -routeUseAutoVia true
setNanoRouteMode -routeWithViaInPin 1:1
setNanoRouteMode -routeWithViaOnlyForStandardCellPin 1:1
routeDesign
optDesign -postRoute
summaryReport -noHtml -outfile outputs/innovus/core_hybrid/vectorless/reports/post_route.sum
redirect outputs/innovus/core_hybrid/vectorless/reports/power_total.rpt { report_power }
redirect outputs/innovus/core_hybrid/vectorless/reports/power_hierarchy.rpt { report_power -hierarchy all }
redirect outputs/innovus/core_hybrid/vectorless/reports/power_inst_a.rpt {report_power -instance $REPORT_INST_A}
redirect outputs/innovus/core_hybrid/vectorless/reports/power_inst_b.rpt {report_power -instance $REPORT_INST_B}
saveDesign outputs/innovus/core_hybrid/vectorless/enc/core_hybrid.enc
defOut -netlist -floorplan -routing outputs/innovus/core_hybrid/vectorless/enc/core_hybrid.def

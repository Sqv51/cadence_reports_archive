source lib_setup.tcl

if {![info exists ::env(DESIGN)] || ![info exists ::env(TOP_MODULE)] || ![info exists ::env(SDC_FILE)] || ![info exists ::env(RTL_MODE)] || ![info exists ::env(BIRISCV_ROOT)]} {
    puts "ERROR: Missing one or more required env vars: DESIGN TOP_MODULE SDC_FILE RTL_MODE BIRISCV_ROOT"
    exit 2
}

set DESIGN     $::env(DESIGN)
set TOP_MODULE $::env(TOP_MODULE)
set sdc        $::env(SDC_FILE)
set RTL_MODE   $::env(RTL_MODE)
set BIRISCV_ROOT $::env(BIRISCV_ROOT)

set OUTPUTS_PATH  "outputs/genus/${DESIGN}/syn_output"
set REPORTS_PATH  "outputs/genus/${DESIGN}/syn_rpt"
set HANDOFF_PATH  "outputs/genus/${DESIGN}/syn_handoff"

foreach d [list $OUTPUTS_PATH $REPORTS_PATH $HANDOFF_PATH] {
    if {![file exists $d]} { file mkdir $d }
}

set_db max_cpus_per_server 16
set_db super_thread_servers "localhost"
set_db hdl_flatten_complex_port true
set_db hdl_record_naming_style %s_%s
set_db auto_ungroup none

set list_lib $libworst
set link_library $list_lib
set target_library $list_lib
set_db library $list_lib

set_db hdl_language sv

set core_dir "${BIRISCV_ROOT}/src/core"

if {$RTL_MODE == "core"} {
    set rtl_all [glob -nocomplain ${core_dir}/*.v]
} elseif {$RTL_MODE == "mul"} {
    set rtl_all [list \
        ${core_dir}/biriscv_defs.v \
        ${core_dir}/biriscv_multiplier.v \
    ]
} elseif {$RTL_MODE == "mule"} {
    set rtl_all [list \
        ${core_dir}/biriscv_defs.v \
        ${core_dir}/biriscv_multiplier_efficient.v \
    ]
} else {
    puts "ERROR: Unsupported RTL_MODE=$RTL_MODE"
    exit 3
}

if {[llength $rtl_all] == 0} {
    puts "ERROR: No RTL files found for mode=$RTL_MODE"
    exit 4
}

set read_args [list]
foreach rtl_file $rtl_all {
    lappend read_args $rtl_file
}
eval read_hdl -sv $read_args

elaborate $TOP_MODULE
read_sdc $sdc
init_design

check_design -unresolved
check_timing_intent
report_ple > ${REPORTS_PATH}/ple.rpt

syn_generic
write_reports -directory ${REPORTS_PATH} -tag generic
write_db  ${OUTPUTS_PATH}/${DESIGN}_generic.db

syn_map
write_reports -directory ${REPORTS_PATH} -tag map
write_db  ${OUTPUTS_PATH}/${DESIGN}_map.db

syn_opt
write_reports -directory ${REPORTS_PATH} -tag final
write_db ${OUTPUTS_PATH}/${DESIGN}_opt.db

report_messages > ${REPORTS_PATH}/${DESIGN}_messages.rpt
report_gates > ${REPORTS_PATH}/${DESIGN}_gates.rpt
report_power > ${REPORTS_PATH}/${DESIGN}_power_vectorless.rpt
report_area > ${REPORTS_PATH}/${DESIGN}_area.rpt

write_sdc > ${HANDOFF_PATH}/${DESIGN}.sdc
write_hdl > ${HANDOFF_PATH}/${DESIGN}.v

exit

#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Mon Jun  8 21:55:56 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v25.12-s079_1 (64bit) 11/18/2025 12:56 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: NanoRoute 25.12-s079_1 NR251112-0044/25_12-UB (database version 18.20.680) {superthreading v2.20}
#@(#)CDS: AAE 25.12-s028 (64bit) 11/18/2025 (Linux 4.18.0-305.el8.x86_64)
#@(#)CDS: CTE 25.12-s024_1 () Nov 12 2025 02:41:04 ( )
#@(#)CDS: SYNTECH 25.12-s006_1 () Oct 30 2025 11:18:17 ( )
#@(#)CDS: CPE v25.12-s020
#@(#)CDS: IQuantus/TQuantus 24.1.0-s365 (64bit) Mon Oct 13 00:44:28 PDT 2025 (Linux 4.18.0-305.el8.x86_64)

#@ source /home/ykaraagac/cadence-bitirme/Flows/NanGate45/biriscv_2mul_vs_hybrid/scripts/cadence/report_power_from_saved_db.tcl
#@ Begin verbose source (pre): source /home/ykaraagac/cadence-bitirme/Flows/NanGate45/biriscv_2mul_vs_hybrid/scripts/cadence/report_power_from_saved_db.tcl
if {![info exists ::env(ENC_SCRIPT)] || ![info exists ::env(REPORT_DIR)]} {...}
set ENC_SCRIPT   $::env(ENC_SCRIPT)
set REPORT_DIR   $::env(REPORT_DIR)
set VCD_FILE     ""
set VCD_SCOPE    ""
set VCD_CLOCK_NAME "clk"
set VCD_CLOCK_SCALE_FACTOR "1.0"
set REPORT_INST_A ""
set REPORT_INST_B ""
if {[info exists ::env(VCD_FILE)]} {
set VCD_FILE $::env(VCD_FILE) 
}
if {[info exists ::env(VCD_SCOPE)]} {
set VCD_SCOPE $::env(VCD_SCOPE) 
}
if {[info exists ::env(VCD_CLOCK_NAME)]} {
set VCD_CLOCK_NAME $::env(VCD_CLOCK_NAME) 
}
if {[info exists ::env(VCD_CLOCK_SCALE_FACTOR)]} {
set VCD_CLOCK_SCALE_FACTOR $::env(VCD_CLOCK_SCALE_FACTOR) 
}
if {[info exists ::env(REPORT_INST_A)]} {
set REPORT_INST_A $::env(REPORT_INST_A) 
}
if {[info exists ::env(REPORT_INST_B)]} {
set REPORT_INST_B $::env(REPORT_INST_B) 
}
if {![file exists $ENC_SCRIPT]} {...}
file mkdir $REPORT_DIR
#@ source $ENC_SCRIPT
#@ Begin verbose source /home/ykaraagac/cadence-bitirme/Flows/NanGate45/biriscv_2mul_vs_hybrid/scripts/cadence/outputs/innovus/core_hybrid_100/vcd/enc/core_hybrid_100.enc (pre)
if {[is_common_ui_mode]} {
read_db [file dirname [file normalize [info script]]]/core_hybrid_100.enc.dat
}
#@ End verbose source /home/ykaraagac/cadence-bitirme/Flows/NanGate45/biriscv_2mul_vs_hybrid/scripts/cadence/outputs/innovus/core_hybrid_100/vcd/enc/core_hybrid_100.enc
if {[string length $VCD_FILE] > 0} {
if {![file exists $VCD_FILE]} {...}
read_activity_file -reset
if {[string length $VCD_SCOPE] > 0} {
read_activity_file -format VCD $VCD_FILE -scope $VCD_SCOPE
}
if {$VCD_CLOCK_SCALE_FACTOR ne "1.0"} {...}
}
catch {summaryReport -noHtml -outfile ${REPORT_DIR}/post_route.sum}
redirect ${REPORT_DIR}/power_total.rpt { report_power }
redirect ${REPORT_DIR}/power_hierarchy.rpt { report_power -hierarchy all }
if {[string length $REPORT_INST_A] > 0} {
redirect ${REPORT_DIR}/power_inst_a.rpt {report_power -insts $REPORT_INST_A}
}
if {[string length $REPORT_INST_B] > 0} {
redirect ${REPORT_DIR}/power_inst_b.rpt {report_power -insts $REPORT_INST_B}
}
exit

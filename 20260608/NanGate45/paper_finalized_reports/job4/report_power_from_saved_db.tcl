if {![info exists ::env(ENC_SCRIPT)] || ![info exists ::env(REPORT_DIR)]} {
    puts "ERROR: Missing required env vars: ENC_SCRIPT REPORT_DIR"
    exit 2
}

set ENC_SCRIPT   $::env(ENC_SCRIPT)
set REPORT_DIR   $::env(REPORT_DIR)
set VCD_FILE     ""
set VCD_SCOPE    ""
set VCD_CLOCK_NAME "clk"
set VCD_CLOCK_SCALE_FACTOR "1.0"
set REPORT_INST_A ""
set REPORT_INST_B ""

if {[info exists ::env(VCD_FILE)]}      { set VCD_FILE $::env(VCD_FILE) }
if {[info exists ::env(VCD_SCOPE)]}     { set VCD_SCOPE $::env(VCD_SCOPE) }
if {[info exists ::env(VCD_CLOCK_NAME)]} { set VCD_CLOCK_NAME $::env(VCD_CLOCK_NAME) }
if {[info exists ::env(VCD_CLOCK_SCALE_FACTOR)]} { set VCD_CLOCK_SCALE_FACTOR $::env(VCD_CLOCK_SCALE_FACTOR) }
if {[info exists ::env(REPORT_INST_A)]} { set REPORT_INST_A $::env(REPORT_INST_A) }
if {[info exists ::env(REPORT_INST_B)]} { set REPORT_INST_B $::env(REPORT_INST_B) }

if {![file exists $ENC_SCRIPT]} {
    puts "ERROR: ENC script not found: $ENC_SCRIPT"
    exit 3
}

file mkdir $REPORT_DIR

source $ENC_SCRIPT

if {[string length $VCD_FILE] > 0} {
    if {![file exists $VCD_FILE]} {
        puts "ERROR: VCD file not found: $VCD_FILE"
        exit 4
    }
    read_activity_file -reset
    if {[string length $VCD_SCOPE] > 0} {
        read_activity_file -format VCD $VCD_FILE -scope $VCD_SCOPE
    } else {
        read_activity_file -format VCD $VCD_FILE
    }
    if {$VCD_CLOCK_SCALE_FACTOR ne "1.0"} {
        puts "INFO: Scaling VCD clock activity for $VCD_CLOCK_NAME by $VCD_CLOCK_SCALE_FACTOR"
        set_switching_activity -clock $VCD_CLOCK_NAME -scale_factor $VCD_CLOCK_SCALE_FACTOR
    }
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

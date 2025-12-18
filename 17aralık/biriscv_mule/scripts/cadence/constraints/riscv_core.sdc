# SDC Constraints for biRISC-V on ASAP7 (7nm technology)

# Set units
set_time_unit -nanoseconds
set_units -time ns

# Clock parameters for ASAP7 (7nm process, moderate frequency)
# Targeting ~500 MHz (2.0ns period) to ease timing
set CLOCK_PERIOD 2.0

# Auto-compute timing constraints (percentages of clock period)
set CLOCK_UNCERTAINTY_SETUP [expr $CLOCK_PERIOD * 0.10]
set CLOCK_UNCERTAINTY_HOLD  [expr $CLOCK_PERIOD * 0.05]
set CLOCK_TRANSITION        [expr $CLOCK_PERIOD * 0.05]
set INPUT_DELAY_MAX        [expr $CLOCK_PERIOD * 0.15]
set INPUT_DELAY_MIN        [expr $CLOCK_PERIOD * 0.05]
set OUTPUT_DELAY_MAX       [expr $CLOCK_PERIOD * 0.15]
set OUTPUT_DELAY_MIN       [expr $CLOCK_PERIOD * 0.05]

# Clock definition (top-level port is clk_i)
create_clock -name clk -period $CLOCK_PERIOD [get_ports clk_i]

# Clock uncertainty and transition
set_clock_uncertainty -setup $CLOCK_UNCERTAINTY_SETUP [get_clocks clk]
set_clock_uncertainty -hold $CLOCK_UNCERTAINTY_HOLD [get_clocks clk]
set_clock_transition $CLOCK_TRANSITION [get_clocks clk]

# Input delays (all inputs except clock/reset)
set_input_delay -clock clk -max $INPUT_DELAY_MAX [remove_from_collection [all_inputs] [get_ports {clk_i rst*}]]
set_input_delay -clock clk -min $INPUT_DELAY_MIN [remove_from_collection [all_inputs] [get_ports {clk_i rst*}]]

# Remove input delays from clock and reset
set_input_delay -clock clk 0 [get_ports clk_i] -add
if {[catch {set_input_delay -clock clk 0 [get_ports rst*] -add} err]} {
    # Reset port may not exist or have different name
}

# Output delays
set_output_delay -clock clk -max $OUTPUT_DELAY_MAX [all_outputs]
set_output_delay -clock clk -min $OUTPUT_DELAY_MIN [all_outputs]

# Optional: Disable timing on specific signals if needed
# (e.g., test signals, trace outputs)
# set_false_path -through [get_ports trace_*]

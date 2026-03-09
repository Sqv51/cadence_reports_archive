# =============================================================================
# SDC Constraints for biRISC-V Low-Power Synthesis
# Technology: NanGate45 (45nm)
# Clock: 100 MHz (10 ns period) - relaxed for maximum power optimization
# =============================================================================

set_time_unit -nanoseconds
set_units -time ns

# Clock: 100 MHz = 10 ns period (intentionally relaxed)
set CLOCK_PERIOD 10.0

# Conservative timing margins
set CLOCK_UNCERTAINTY_SETUP [expr $CLOCK_PERIOD * 0.10]
set CLOCK_UNCERTAINTY_HOLD  [expr $CLOCK_PERIOD * 0.05]
set CLOCK_TRANSITION        [expr $CLOCK_PERIOD * 0.05]
set INPUT_DELAY_MAX         [expr $CLOCK_PERIOD * 0.15]
set INPUT_DELAY_MIN         [expr $CLOCK_PERIOD * 0.05]
set OUTPUT_DELAY_MAX        [expr $CLOCK_PERIOD * 0.15]
set OUTPUT_DELAY_MIN        [expr $CLOCK_PERIOD * 0.05]

# Clock definition
create_clock -name clk -period $CLOCK_PERIOD [get_ports clk_i]

# Clock quality
set_clock_uncertainty -setup $CLOCK_UNCERTAINTY_SETUP [get_clocks clk]
set_clock_uncertainty -hold  $CLOCK_UNCERTAINTY_HOLD  [get_clocks clk]
set_clock_transition  $CLOCK_TRANSITION [get_clocks clk]

# I/O delays
set_input_delay  -clock clk -max $INPUT_DELAY_MAX [get_ports {*}]
set_input_delay  -clock clk -min $INPUT_DELAY_MIN [get_ports {*}]

# Zero delay on clock port itself
set_input_delay  -clock clk 0 [get_ports clk_i] -add

# Reset port (if present)
if {[catch {set_input_delay -clock clk 0 [get_ports rst_i] -add} err]} {
    # rst_i may not exist
}

# Output delays
set_output_delay -clock clk -max $OUTPUT_DELAY_MAX [get_ports {*}]
set_output_delay -clock clk -min $OUTPUT_DELAY_MIN [get_ports {*}]

# Don't touch the clock network - let CTS handle it
set_dont_touch_network [get_clocks clk]

# =============================================================================
# Power intent: Set maximum transition and capacitance for low-power
# Adjusted for NanGate45 (45nm) process
# =============================================================================
set_max_transition [expr $CLOCK_PERIOD * 0.10] [current_design]
set_max_capacitance 0.1 [current_design]

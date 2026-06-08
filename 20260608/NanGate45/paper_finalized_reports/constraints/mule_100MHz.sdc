create_clock -name clk -period 10.000 [get_ports clk_i]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay 2.0 -clock clk [remove_from_collection [all_inputs] [get_ports {clk_i rst_i}]]
set_output_delay 2.0 -clock clk [all_outputs]
set_false_path -from [get_ports rst_i]
set_max_area 0

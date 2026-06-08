create_clock -name clk -period 2.000 [get_ports clk_i]
set_clock_uncertainty 0.01 [get_clocks clk]
set_input_delay 0.4 -clock clk [remove_from_collection [all_inputs] [get_ports {clk_i rst_i}]]
set_output_delay 0.4 -clock clk [all_outputs]
set_false_path -from [get_ports rst_i]
set_max_area 0

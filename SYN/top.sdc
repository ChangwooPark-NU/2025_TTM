# Clock
create_clock -name clk -period 10 [get_ports clk]

# IO delays (adjust numbers later)
set_input_delay  -clock [get_clocks clk] -max 0.2 [remove_from_collection [all_inputs] [get_ports {clk}]]
set_input_delay  -clock [get_clocks clk] -min 0.0 [remove_from_collection [all_inputs] [get_ports {clk}]]

set_output_delay -clock [get_clocks clk] -max 0.2 [all_outputs]
set_output_delay -clock [get_clocks clk] -min 0.0 [all_outputs]

# Do not time async reset
set_false_path -from [get_ports rst] -to [all_registers]

# Loads / caps (tune later for Innovus)
set_load 0.050 [all_outputs]
set_max_capacitance 0.010 [all_inputs]

# Clock uncertainty
set_clock_uncertainty -setup 0.03 [get_clocks clk]
set_clock_uncertainty -hold  0.06 [get_clocks clk]

set_max_transition 0.12 [current_design]

# Optional (often used in Genus scripts)
set_db use_scan_seqs_for_non_dft false



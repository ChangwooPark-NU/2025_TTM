# Constraints 

# Define clock (period in ns) 
create_clock -name clk -period 10 [get_ports clk]

# Set input + output delays
set_input_delay -clock [get_clocks clk] -max 0.2 [get_ports {en INPUT_MEM_DOUT[*] Wq_MEM_DOUT[*]}]
set_input_delay -clock [get_clocks clk] -min 0.0 [get_ports {en INPUT_MEM_DOUT[*] Wq_MEM_DOUT[*]}]

set_output_delay -clock [get_clocks clk] -max 0.2 [get_ports {valid out[*] INPUT_MEM_WEN INPUT_MEM_CEB INPUT_MEM_ADDR[*] Wq_MEM_WEN Wq_MEM_CEB Wq_MEM_ADDR[*]}]
set_output_delay -clock [get_clocks clk] -min 0.0 [get_ports {valid out[*] INPUT_MEM_WEN INPUT_MEM_CEB INPUT_MEM_ADDR[*] Wq_MEM_WEN Wq_MEM_CEB Wq_MEM_ADDR[*]}]

# Don't analyze timing on asynchronous reset
set_false_path -from [get_ports rst] -to [all_registers]

# Set 50fF load capacitances
set_load 0.050 [all_outputs]

# Max capacitance on inputs
set_max_capacitance 0.010 [all_inputs]

# Account for skew + jitter
set_clock_uncertainty -setup 0.03 [get_clocks clk]
set_clock_uncertainty -hold 0.06 [get_clocks clk]

set_max_transition 0.12 [current_design]

set_db use_scan_seqs_for_non_dft false


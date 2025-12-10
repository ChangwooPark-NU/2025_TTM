# Makefile

run: 
	xrun -sv -64bit -access r divider.v scale.sv scale_tb.sv

gui: 
	xrun -sv -64bit -gui -access r divider.v scale.sv scale_tb.sv
	

clean: 
	rm -rf *.history *.shm *.log *.txt *.d *.key *.vcd *.txt *.data *.diag *.csv

.PHONY: run clean gui

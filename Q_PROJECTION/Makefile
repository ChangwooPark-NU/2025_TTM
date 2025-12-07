# Makefile

run: 
	xrun -sv -64bit -svseed random +notimingchecks -access r int_to_fp.v input_mem_tt0p9v25c.v Wq_mem_tt0p9v25c.v q_proj_mem_tt0p9v25c.v cap.sv fifo1.sv fifo3.sv pe.sv fifo2.sv fifo4.sv  output.sv  ps.sv  sys_array1.sv counter.sv black_box.sv Q_projection.sv Q_projection_TB.sv
	python3 golden_model.py 
	diff -w golden_out_tiles_fp32.txt fp32.txt
	@diff -w golden_out_tiles_fp32.txt fp32.txt > /tmp/q_diff.$$ ; \
	if [ $$? -eq 0 ]; then \
		echo ""; \
		echo "Golden reference and RTL match"; \
		echo ""; \
		rm /tmp/q_diff.$$; \
	else \
		echo "Golden reference and RTL MISMATCH (see diff below):"; \
		cat /tmp/q_diff.$$; \
		rm /tmp/q_diff.$$; \
		exit 1; \
	fi	
clean: 
	rm -rf *.history *.shm *.log *.txt *.d *.key *.vcd *.txt *.data *.diag *.csv

.PHONY: run clean 

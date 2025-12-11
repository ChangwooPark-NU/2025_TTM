# Makefile

run: 
	xrun -sv -64bit -svseed random +notimingchecks -access r scale.sv score.v softmax_4x4.v  softmax.v exponential.v divider.v multiplier.v  gemm_4x4_4x32_mha4.sv  gemm_4x4_4x32_stream.sv multiplier.v adder.sv regfile.sv regfile2.sv regfile3.sv int_to_fp.v input_mem_tt0p9v25c.v Wq_mem_tt0p9v25c.v q_proj_mem_tt0p9v25c.v cap.sv fifo1.sv fifo3.sv pe.sv fifo2.sv fifo4.sv  output.sv  sys_array1.sv counter.sv black_box.sv attn_top_4x4_128.sv Q_projection.sv top.sv Q_projection_TB.sv
	python3 tol_extend.py	

gui: 
	xrun -sv -64bit -gui -svseed random +notimingchecks -access r scale.sv score.v softmax_4x4.v  softmax.v exponential.v divider.v multiplier.v  gemm_4x4_4x32_mha4.sv  gemm_4x4_4x32_stream.sv multiplier.v adder.sv regfile.sv regfile2.sv regfile3.sv int_to_fp.v input_mem_tt0p9v25c.v Wq_mem_tt0p9v25c.v q_proj_mem_tt0p9v25c.v cap.sv fifo1.sv fifo3.sv pe.sv fifo2.sv fifo4.sv  output.sv  sys_array1.sv counter.sv black_box.sv attn_top_4x4_128.sv Q_projection.sv top.sv Q_projection_TB.sv
	python3 tol_extend.py	
clean: 
	rm -rf *.cmd* *.log* *.history *.shm *.log *.txt *.d *.key *.vcd *.txt *.data *.diag *.csv

.PHONY: run clean 

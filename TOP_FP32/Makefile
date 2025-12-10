XRUN := xrun
TOP  := attn_top_4x4_128_tb
LOG  := xrun.log

TIMING ?= off
DUMP   ?= 0

BASE_OPTS := -64bit -sv -access +r -top $(TOP) -l $(LOG)
TIMING_OFF_OPTS := -notimingchecks +no_tchk_msg

DUMP_OPTS :=
ifeq ($(DUMP),1)
DUMP_OPTS += +define+DUMP_VCD
endif

XRUN_OPTS := $(BASE_OPTS) $(DUMP_OPTS)
ifeq ($(TIMING),off)
XRUN_OPTS += $(TIMING_OFF_OPTS)
endif

VPROJ_MEM_RTL := v_proj_mem_tt0p9v25c.v

SRCS := \
  attn_top_4x4_128.sv \
  attn_top_4x4_128_tb.sv \
  sram128x128_vproj.sv\
  score.v \
  softmax_4x4.v \
  softmax.v \
  exponential.v \
  divider.v \
  gemm_4x4_4x32_mha4.sv \
  gemm_4x4_4x32_stream.sv\
  multiplier.v \
  adder.v \
  $(VPROJ_MEM_RTL)

.PHONY: run gui clean

run:
	$(XRUN) $(XRUN_OPTS) $(SRCS)

gui:
	$(XRUN) $(XRUN_OPTS) -gui $(SRCS)

clean:
	rm -rf INCA_libs xcelium.d xrun.* *.log *.key *.history *.shm *.vcd

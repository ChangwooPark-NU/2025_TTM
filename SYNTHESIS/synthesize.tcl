# Cadence Genus(TM) Synthesis Solution, Version 21.15-s080_1, built Sep 23 2022 12:57:55

# Date: Mon Apr 29 15:32:23 2024
# # Host: jg2.ece.northwestern.edu (x86_64 w/Linux 3.10.0-1160.76.1.el7.x86_64) (64cores*128cpus*1physical cpu*AMD Ryzen Threadripper 3990X 64-Core Processor 512KB)
# # OS:   Red Hat Enterprise Linux Server release 7.9 (Maipo)
#
set_db max_cpus_per_server 32
read_hdl -sv -f filelist.f
set_db library  "/vlsi/technology/TSMC/28nm/TSMC_IP/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/INPUT_SRAM/input_mem/NLDM/input_mem_tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/Weight_SRAM/Wq_SRAM/Wq_mem/NLDM/Wq_mem_tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/OUTPUT_SRAM/Q_Proj_mem/q_proj_mem/NLDM/q_proj_mem_tt0p9v25c.lib"

set_db lef_library "/vlsi/technology/TSMC/28nm/TSMC_IP/tsmcn28_9lm6X1Z1UUTRDL_11_30_22.tlef /vlsi/technology/TSMC/28nm/TSMC_IP/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp30p140_110a/lef/tcbn28hpcplusbwp30p140.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/INPUT_SRAM/input_mem/LEF/input_mem.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/Weight_SRAM/Wq_SRAM/Wq_mem/LEF/Wq_mem.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/OUTPUT_SRAM/Q_Proj_mem/q_proj_mem/LEF/q_proj_mem.lef" 

set_db auto_ungroup none
set_db lp_insert_clock_gating true
set_db lp_clock_gating_prefix MYCGsi
elaborate Q_Projection  
current_design Q_Projection 
read_sdc q_proj.sdc
syn_generic
syn_map
syn_opt
report_timing > timing.rpt
report_area > area.rpt
report_power > power.rpt
write_hdl > q_proj_syn.v
write_sdc > q_proj_syn.sdc

set_db max_cpus_per_server 32
set_db lp_insert_clock_gating false 

read_hdl -sv -f filelist.f 

set_db library  "/vlsi/technology/TSMC/28nm/TSMC_IP/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/INPUT_SRAM/input_mem/NLDM/input_mem_tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/OUTPUT_SRAM/Q_Proj_mem/q_proj_mem/NLDM/q_proj_mem_tt0p9v25c.lib /vlsi/users/cpark/projects/2025_TTM/SRAM/Weight_SRAM/Wq_SRAM/Wq_mem/NLDM/Wq_mem_tt0p9v25c.lib"

set_db lef_library "/vlsi/technology/TSMC/28nm/TSMC_IP/tsmcn28_9lm6X1Z1UUTRDL_11_30_22.tlef /vlsi/technology/TSMC/28nm/TSMC_IP/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Back_End/lef/tcbn28hpcplusbwp30p140_110a/lef/tcbn28hpcplusbwp30p140.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/INPUT_SRAM/input_mem/LEF/input_mem.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/OUTPUT_SRAM/Q_Proj_mem/q_proj_mem/LEF/q_proj_mem.lef /vlsi/users/cpark/projects/2025_TTM/SRAM/Weight_SRAM/Wq_SRAM/Wq_mem/LEF/Wq_mem.lef"

set_db auto_ungroup none
set_db lp_insert_clock_gating true
set_db lp_clock_gating_prefix MYCGsi
elaborate top
current_design top
read_sdc top.sdc
syn_generic
syn_map
syn_opt
report_timing > timing.rpt
report_area > area.rpt
report_power > power.rpt
write_hdl > top_syn.v
write_sdc > top_syn.sdc
check_design -unresolved


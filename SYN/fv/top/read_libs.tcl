add_search_path . /vlsi/tools/cadence/GENUS211/tools.lnx86/lib/tech -library -both
read_library -liberty -both \
    /vlsi/technology/TSMC/28nm/TSMC_IP/tcbn28hpcplusbwp30p140_190a/TSMCHOME/digital/Front_End/timing_power_noise/NLDM/tcbn28hpcplusbwp30p140_180a/tcbn28hpcplusbwp30p140tt0p9v25c.lib \
    /vlsi/users/cpark/projects/2025_TTM/SRAM/INPUT_SRAM/input_mem/NLDM/input_mem_tt0p9v25c.lib \
    /vlsi/users/cpark/projects/2025_TTM/SRAM/OUTPUT_SRAM/Q_Proj_mem/q_proj_mem/NLDM/q_proj_mem_tt0p9v25c.lib \
    /vlsi/users/cpark/projects/2025_TTM/SRAM/Weight_SRAM/Wq_SRAM/Wq_mem/NLDM/Wq_mem_tt0p9v25c.lib


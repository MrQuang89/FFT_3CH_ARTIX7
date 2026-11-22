
# PlanAhead Launch Script for Post-Synthesis floorplanning, created by Project Navigator

create_project -name FTT_512_NEW -dir "E:/VHDL-PROJECT/NAM 2025/TEST_NEW_BOARD_03ADC/NEW_CODE_0805/FTT_512_NEW_CH123/planAhead_run_2" -part xc7a100tfgg484-3
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "E:/VHDL-PROJECT/NAM 2025/TEST_NEW_BOARD_03ADC/NEW_CODE_0805/FTT_512_NEW_CH123/top.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {E:/VHDL-PROJECT/NAM 2025/TEST_NEW_BOARD_03ADC/NEW_CODE_0805/FTT_512_NEW_CH123} {Netlist} {ipcore_dir} }
add_files [list {ipcore_dir/FFT_512.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/FFT_OUT_IM.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/fifo_14bits.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/FIFO_OUT_IM.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/FIFO_OUT_RE.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/peak_value_fifo.ncf}] -fileset [get_property constrset [current_run]]
set_property target_constrs_file "pins_config.ucf" [current_fileset -constrset]
add_files [list {pins_config.ucf}] -fileset [get_property constrset [current_run]]
link_design

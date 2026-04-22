# ----------------------------------------------------------------------------
# constraints.xdc — Timing constraints for 100 MHz operation (Xilinx Vivado).
# ----------------------------------------------------------------------------

# 100 MHz system clock (10 ns period)
create_clock -name sys_clk -period 10.000 [get_ports clk]

# Pessimistic input/output delay: assume board-level 2 ns skew
set_input_delay  -clock sys_clk -max 2.000 [all_inputs]
set_input_delay  -clock sys_clk -min 0.500 [all_inputs]
set_output_delay -clock sys_clk -max 2.000 [all_outputs]
set_output_delay -clock sys_clk -min 0.500 [all_outputs]

# Reset is treated asynchronous, constrain as false path
set_false_path -from [get_ports rst]

# Encourage tool to keep MAC results in DSP48 blocks
set_property USE_DSP48 yes [get_cells -hierarchical -filter {NAME =~ "*u_pe*"}]

# Block RAM style already hinted in bram_controller.sv

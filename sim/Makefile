# ------------------------------------------------------------------------
# Makefile — simulate the 8x8 systolic array with icarus or verilator.
#
#   make             # alias for iverilog
#   make iverilog    # build and run with Icarus
#   make verilator   # build and run with Verilator
#   make clean
# ------------------------------------------------------------------------

RTL_DIR := ../rtl
TB_DIR  := ../tb

RTL_SRCS := \
    $(RTL_DIR)/pe.sv \
    $(RTL_DIR)/skew_injector.sv \
    $(RTL_DIR)/systolic_array.sv \
    $(RTL_DIR)/controller_fsm.sv \
    $(RTL_DIR)/bram_controller.sv \
    $(RTL_DIR)/ping_pong_buffer.sv \
    $(RTL_DIR)/tiling_controller.sv \
    $(RTL_DIR)/accelerator_top.sv

TB_SRCS := $(TB_DIR)/tb_systolic_array.sv

TOP := tb_systolic_array

.PHONY: all iverilog verilator clean

all: iverilog

# ---- Icarus Verilog ----
iverilog: sim.vvp
	vvp sim.vvp

sim.vvp: $(RTL_SRCS) $(TB_SRCS)
	iverilog -g2012 -o sim.vvp -s $(TOP) $(RTL_SRCS) $(TB_SRCS)

# ---- Verilator ----
verilator:
	verilator --binary --timing -Wno-fatal \
	    --top-module $(TOP) \
	    $(RTL_SRCS) $(TB_SRCS) \
	    -o V$(TOP)
	./obj_dir/V$(TOP)

clean:
	rm -rf sim.vvp obj_dir *.vcd

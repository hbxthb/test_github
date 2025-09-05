SIM ?= verilator

RTL_DIR := rtl
UVM_DIR := uvm
TB_DIR  := tb

SRCS := \
  $(RTL_DIR)/sp_def_pkg.sv \
  $(RTL_DIR)/fabric_def_pkg.sv \
  $(RTL_DIR)/dixbar_inport_if.sv \
  $(RTL_DIR)/common_pipe_intf.sv \
  $(RTL_DIR)/xbar_dbg_if.sv \
  $(RTL_DIR)/lib_rr_arbiter.sv \
  $(RTL_DIR)/lib_binenc.sv \
  $(RTL_DIR)/lib_fifo_credit.sv \
  $(RTL_DIR)/SP_XBAR_dlinput.sv \
  $(RTL_DIR)/SP_XBAR_downlink.sv \
  $(UVM_DIR)/xbar_pkg.sv \
  $(TB_DIR)/tb_top.sv

all: run

run:
	@echo "Build and run with $(SIM)"
	@echo "For commercial simulators, compile SRCS accordingly."

clean:
	rm -rf obj_dir logs *.log *.vvp *.vcd

.PHONY: all run clean


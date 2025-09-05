`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import sp_def_pkg::*;
import fabric_def_pkg::*;
import xbar_pkg::*;

`include "../rtl/dixbar_inport_if.sv"
`include "../rtl/common_pipe_intf.sv"
`include "../rtl/xbar_dbg_if.sv"

module tb_top;
  localparam int IN_NUM = 8;
  localparam int OT_NUM = 8;
  localparam int DATA_WIDTH = 256;

  logic clk; logic reset_n;
  always #5ns clk = ~clk;

  // Interfaces
  dixbar_inport_if #(DATA_WIDTH, 3) in_if[IN_NUM]();
  common_pipe_intf #(DATA_WIDTH)    out_if[OT_NUM]();
  xbar_dbg_if #(IN_NUM, OT_NUM)     dbg_if();

  // DUT
  SP_XBAR_downlink #(.IN_NUM(IN_NUM), .OT_NUM(OT_NUM), .DATA_WIDTH(DATA_WIDTH)) dut (
    .clk(clk), .reset_n(reset_n), .dixbar_state(),
    .inport(in_if), .outport(out_if), .dbg_if(dbg_if)
  );

  // Hook prdy to 1
  initial begin
    for (int i=0;i<OT_NUM;i++) out_if[i].prdy = 1'b1;
  end

  // Clock/Reset
  initial begin
    clk = 0; reset_n = 0;
    #100ns; reset_n = 1;
  end

  // UVM config hookups
  initial begin
    uvm_config_int::set(null, "*", "IN_NUM", IN_NUM);
    for (int i=0;i<IN_NUM;i++) begin
      uvm_config_db#(virtual dixbar_inport_if)::set(null, $sformatf("*.env.drv%0d*", i), "vif", in_if[i]);
    end
    uvm_config_db#(virtual common_pipe_intf[$])::set(null, "*.env.outm*", "vifs", out_if);
    uvm_config_db#(virtual xbar_dbg_if)::set(null, "*.env.dbgmon*", "vif", dbg_if);
    run_test("xbar_base_test");
  end

endmodule


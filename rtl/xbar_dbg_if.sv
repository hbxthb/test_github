interface xbar_dbg_if #(
  parameter int L1_NUM = 8,
  parameter int L2_NUM = 8,
  parameter int PRI_WTH = (L1_NUM <= 2) ? 1 : $clog2(L1_NUM)
);
  logic clk;
  logic [L2_NUM-1:0]                 vld;
  logic [L2_NUM-1:0][PRI_WTH-1:0]    sel;
endinterface : xbar_dbg_if


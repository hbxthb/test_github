interface dixbar_inport_if #(
  parameter int DATA_WIDTH = 256,
  parameter int VOQ_SIZE_W = 3
);

  import fabric_def_pkg::*;

  logic clk;
  // request path (to XBAR)
  logic             req_valid;
  req2xbar_t        req_pd;

  // data path (to XBAR)
  logic             data_valid;
  logic [DATA_WIDTH-1:0] data;
  logic             data_prdy;   // beat accepted by XBAR when 1

  // grant/feedback (from XBAR)
  logic [VOQ_SIZE_W:0] grant_id;      // {valid, id}
  logic [2:0]          grant_burst;   // burst length for granted VOQ

  // modports
  modport receive (
    input  req_valid, req_pd, data_valid, data,
    output grant_id, grant_burst,
    output data_prdy
  );

endinterface : dixbar_inport_if


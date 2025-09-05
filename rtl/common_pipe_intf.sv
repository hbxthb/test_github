interface common_pipe_intf #(
  parameter int DATA_WIDTH = 256
);

  logic clk;
  logic                 pvld;
  logic                 prdy;
  logic [DATA_WIDTH-1:0] data;

  modport send (
    output pvld, data,
    input  prdy
  );

endinterface : common_pipe_intf


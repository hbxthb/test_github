// Simple parameterizable round-robin arbiter
module rr_arbiter #(
  parameter int N = 8,
  parameter int W = (N <= 2) ? 1 : $clog2(N)
)(
  input  logic             clk,
  input  logic             reset_n,
  input  logic [N-1:0]     enq,
  input  logic [W-1:0]     pri,
  output logic [N-1:0]     winner_onehot,
  output logic             winner_valid,
  output logic [W-1:0]     winner_encode
);

  logic [N-1:0] rotated;
  logic [N-1:0] grant_rot;
  logic [W-1:0] idx;

  // rotate enq by pri
  assign rotated = (enq << pri) | (enq >> (N - pri));

  // first-one-hot
  function automatic [N-1:0] first_onehot(input [N-1:0] v);
    first_onehot = '0;
    for (int i=0; i<N; i++) begin
      if (v[i]) begin
        first_onehot[i] = 1'b1;
        break;
      end
    end
  endfunction

  assign grant_rot     = first_onehot(rotated);
  assign winner_valid  = |enq;
  assign winner_onehot = (grant_rot >> pri) | (grant_rot << (N - pri));

  // binary encode
  always_comb begin
    idx = '0;
    for (int i=0; i<N; i++) if (winner_onehot[i]) idx = i[W-1:0];
  end
  assign winner_encode = idx;

endmodule


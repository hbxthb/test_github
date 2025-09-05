// Onehot to binary encoder
module binenc #(
  parameter int N = 8,
  parameter int W = (N <= 2) ? 1 : $clog2(N)
)(
  input  logic [N-1:0] A,
  output logic [W-1:0] ADDR
);
  always_comb begin
    ADDR = '0;
    for (int i=0; i<N; i++) if (A[i]) ADDR = i[W-1:0];
  end
endmodule


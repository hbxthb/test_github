module fifo_credit #(
  parameter int WIDTH = 256,
  parameter int DEPTH = 32,
  parameter int CREDIT_W = 6
)(
  input  logic                 clk,
  input  logic                 reset_n,
  // enq
  input  logic                 enq,
  input  logic [WIDTH-1:0]     enq_data,
  // deq
  input  logic                 deq,
  output logic [WIDTH-1:0]     deq_data,
  output logic                 empty,
  output logic                 deq_prdy,
  // credit
  output logic [CREDIT_W-1:0]  credit
);

  localparam int AW = (DEPTH <= 2) ? 1 : $clog2(DEPTH);

  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [AW:0] wptr, rptr; // one extra bit to detect full/empty

  wire full;
  assign full  = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
  assign empty = (wptr == rptr);

  assign deq_prdy = ~full;

  // credit equals available slots
  assign credit = CREDIT_W'((DEPTH - (wptr - rptr)));

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      wptr <= '0;
      rptr <= '0;
    end else begin
      if (enq && !full) begin
        mem[wptr[AW-1:0]] <= enq_data;
        wptr <= wptr + 1'b1;
      end
      if (deq && !empty) begin
        rptr <= rptr + 1'b1;
      end
    end
  end

  assign deq_data = mem[rptr[AW-1:0]];

endmodule


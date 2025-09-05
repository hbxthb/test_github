import sp_def_pkg::*;
import fabric_def_pkg::*;

module SP_XBAR_dlinput #(
  parameter int DEPTH = 8,
  parameter int SIZE  = (DEPTH <= 2) ? 1 : $clog2(DEPTH)
)(
  input  logic             clk,
  input  logic             reset_n,

  // from initiator request
  input  logic             input_valid,
  input  req2xbar_t        input_pd,

  // to Initiator, grant
  output logic [SIZE:0]    g1_grant_id,
  output logic [2:0]       g1_grant_burst,
  output logic [2:0]       grant_burst,

  // to xbar arb
  output logic [7:0]       arb,
  output logic [7:0][2:0]  arb_burst,

  // from xbar arb (onehot per VOQ 0..7)
  input  logic [7:0]       win_vec
);

  // per-VOQ head/tail indices into entry space (0..DEPTH-1)
  logic [7:0][SIZE-1:0] head, tail, head_nxt;
  logic [7:0]           head_update, tail_update;
  logic [7:0]           valid, valid_nxt;
  logic                 valid_update;

  // per-entry request id linking (next pointer) and burst length storage
  logic [DEPTH-1:0][SIZE-1:0] nxt_pointer;
  logic [DEPTH-1:0]           nxt_pointer_update;
  logic [SIZE-1:0]            nxt_pointer_nxt;

  logic [DEPTH-1:0][2:0]      entry_pd;
  logic [DEPTH-1:0]           entry_update;
  logic [2:0]                 entry_pd_nxt;

  // selected id/burst
  logic [SIZE-1:0] win_id, req_id, input_tail;
  logic [2:0]      win_burst;
  logic [2:0]      voq_id;

  // entry count and full flag (optional)
  logic [7:0] entry_cnt, entry_cnt_nxt;

  // outputs
  assign grant_burst   = win_burst;
  assign g1_grant_burst = win_burst;

  // registers
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      valid     <= '0;
      entry_cnt <= '0;
    end else begin
      if (valid_update) begin
        valid     <= valid_nxt;
        entry_cnt <= entry_cnt_nxt;
      end
    end
  end

  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      foreach (entry_pd[i]) entry_pd[i] <= '0;
      foreach (nxt_pointer[i]) nxt_pointer[i] <= '0;
      foreach (tail[i]) tail[i] <= '0;
      foreach (head[i]) head[i] <= '0;
    end else begin
      foreach (entry_pd[i]) if (entry_update[i]) entry_pd[i] <= entry_pd_nxt;
      foreach (nxt_pointer[i]) if (nxt_pointer_update[i]) nxt_pointer[i] <= nxt_pointer_nxt;
      foreach (tail[i]) if (tail_update[i]) tail[i] <= req_id;
      foreach (head[i]) if (head_update[i]) head[i] <= head_nxt[i];
    end
  end

  // comb
  always_comb begin
    // defaults
    tail_update          = '0;
    nxt_pointer_update   = '0;
    entry_update         = '0;
    valid_update         = 1'b0;
    valid_nxt            = valid;
    arb                  = valid;
    for (int i=0;i<8;i++) arb_burst[i] = entry_pd[head[i]];

    // input parse
    voq_id   = input_pd.voq_id;
    req_id   = input_pd.req_id[SIZE-1:0];
    entry_pd_nxt = input_pd.burst_length; // store raw length

    // enqueue behavior
    tail_update[voq_id] = input_valid;
    input_tail = tail[voq_id];
    nxt_pointer_nxt = req_id;
    if (valid[voq_id]) nxt_pointer_update[input_tail] = input_valid;
    entry_update[req_id] = input_valid;

    // head bypass: if win now or empty queue taking first element
    logic [7:0] head_bypass;
    for (int i=0;i<8;i++) begin
      head_bypass[i] = (((head[i] == tail[i]) && win_vec[i]) || !valid[i]) && (voq_id == i[2:0]) && input_valid;
      head_nxt[i]    = head_bypass[i] ? req_id : nxt_pointer[head[i]];
      head_update[i] = (((head[i] != tail[i]) && win_vec[i]) || head_bypass[i]);
    end

    // valid update
    valid_update = (|win_vec) || input_valid;
    if (|win_vec) begin
      for (int i=0;i<8;i++) if (win_vec[i]) valid_nxt[i] = !(head[i] == tail[i]);
    end
    if (input_valid) valid_nxt[voq_id] = 1'b1;

    // winner select
    unique case (win_vec)
      8'b00000001: win_id = head[0];
      8'b00000010: win_id = head[1];
      8'b00000100: win_id = head[2];
      8'b00001000: win_id = head[3];
      8'b00010000: win_id = head[4];
      8'b00100000: win_id = head[5];
      8'b01000000: win_id = head[6];
      8'b10000000: win_id = head[7];
      default:     win_id = '0;
    endcase

    unique case (win_vec)
      8'b00000001: win_burst = arb_burst[0];
      8'b00000010: win_burst = arb_burst[1];
      8'b00000100: win_burst = arb_burst[2];
      8'b00001000: win_burst = arb_burst[3];
      8'b00010000: win_burst = arb_burst[4];
      8'b00100000: win_burst = arb_burst[5];
      8'b01000000: win_burst = arb_burst[6];
      8'b10000000: win_burst = arb_burst[7];
      default:     win_burst = 3'd0;
    endcase

    // grant id pack {valid, id}
    g1_grant_id    = {(|win_vec), win_id};
    entry_cnt_nxt  = entry_cnt;
    if (valid_update) entry_cnt_nxt = entry_cnt + (input_valid ? 8'd1 : 8'd0) - ((|win_vec) ? 8'd1 : 8'd0);
  end

endmodule


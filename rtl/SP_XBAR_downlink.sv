import sp_def_pkg::*;
import fabric_def_pkg::*;

module SP_XBAR_downlink #(
  parameter int IN_NUM     = 8,
  parameter int OT_NUM     = 8,
  parameter int DELAY_NUM  = 2,
  parameter int VOQ_DEPTH  = 8,
  parameter int DATA_WIDTH = 256
)(
  input  logic                 clk,
  input  logic                 reset_n,
  output sp_status_type_t      dixbar_state,

  // input ports
  dixbar_inport_if.receive     inport[IN_NUM],
  // output ports
  common_pipe_intf.send        outport[OT_NUM],
  // debug
  xbar_dbg_if #(IN_NUM, OT_NUM) dbg_if
);

  localparam int L1_NUM  = IN_NUM;
  localparam int L2_NUM  = OT_NUM;
  localparam int PRI_WTH = (L1_NUM <= 2) ? 1 : $clog2(L1_NUM);

  // per-input VOQ adapter connections
  logic [L1_NUM-1:0][7:0]      l1_arb_array;
  logic [L1_NUM-1:0][7:0][2:0] l1_arb_len;
  logic [L1_NUM-1:0][7:0]      l1_win_vec;
  logic [L1_NUM-1:0][2:0]      l1_grant_burst;
  logic [L1_NUM-1:0][3:0]      l1_grant_id;

  // Selected per-input granted out id and burst countdown
  logic [L1_NUM-1:0][PRI_WTH-1:0] l1_burst_l2_id;
  logic [L1_NUM-1:0][2:0]         l1_burst_cnt;
  logic [L1_NUM-1:0]              l1_burst_active;

  // RR priorities
  logic [PRI_WTH-1:0] l1_wheel, l1_wheel_nxt;
  logic [PRI_WTH-1:0] l2_wheel, l2_wheel_nxt;

  // Per-output arbitration request (qualified by credit and burst conflicts)
  logic [L2_NUM-1:0][L1_NUM-1:0] l2_req;
  logic [L2_NUM-1:0]             l2_req_valid;
  logic [L2_NUM-1:0][L1_NUM-1:0] l2_grant_oh;
  logic [L2_NUM-1:0]             l2_grant_vld;
  logic [L2_NUM-1:0][PRI_WTH-1:0] l2_grant_idx;

  // Output FIFOs
  logic [L2_NUM-1:0]                 out_enq;
  logic [L2_NUM-1:0][DATA_WIDTH-1:0] out_enq_data;
  logic [L2_NUM-1:0]                 out_deq;
  logic [L2_NUM-1:0][DATA_WIDTH-1:0] out_deq_data;
  logic [L2_NUM-1:0]                 out_empty;
  logic [L2_NUM-1:0]                 out_deq_prdy;
  logic [L2_NUM-1:0][5:0]            out_credit;

  // L2 credit mirror for arb qualification
  logic [L2_NUM-1:0][5:0] l2_credit;

  // Data staging from inputs
  logic [L1_NUM-1:0][DATA_WIDTH-1:0] l1_data_q;
  logic [L1_NUM-1:0]                 l1_data_vld_q;

  // Instantiate input VOQ adapters
  generate
    for (genvar i=0;i<L1_NUM;i++) begin: g_in
      SP_XBAR_dlinput #(.DEPTH(VOQ_DEPTH)) u_dl (
        .clk            (clk),
        .reset_n        (reset_n),
        .input_valid    (inport[i].req_valid),
        .input_pd       (inport[i].req_pd),
        .g1_grant_id    (l1_grant_id[i]),
        .g1_grant_burst (l1_grant_burst[i]),
        .grant_burst    (),
        .arb            (l1_arb_array[i]),
        .arb_burst      (l1_arb_len[i]),
        .win_vec        (l1_win_vec[i])
      );
      // Latch input data one cycle for alignment
      always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
          l1_data_q[i]      <= '0;
          l1_data_vld_q[i]  <= 1'b0;
        end else begin
          l1_data_q[i]      <= inport[i].data;
          l1_data_vld_q[i]  <= inport[i].data_valid;
        end
      end

      // grant feedback and accept all data
      assign inport[i].grant_id    = l1_grant_id[i];
      assign inport[i].grant_burst = l1_grant_burst[i];
      assign inport[i].data_prdy   = 1'b1;
    end
  endgenerate

  // Initialize credits mirror from FIFOs
  generate
    for (genvar o=0;o<L2_NUM;o++) begin: g_out_fifo
      fifo_credit #(.WIDTH(DATA_WIDTH), .DEPTH(32), .CREDIT_W(6)) u_of (
        .clk       (clk),
        .reset_n   (reset_n),
        .enq       (out_enq[o]),
        .enq_data  (out_enq_data[o]),
        .deq       (out_deq[o]),
        .deq_data  (out_deq_data[o]),
        .empty     (out_empty[o]),
        .deq_prdy  (out_deq_prdy[o]),
        .credit    (out_credit[o])
      );

      assign outport[o].pvld = ~out_empty[o];
      assign outport[o].data = out_deq_data[o];
      assign out_deq[o]      = outport[o].pvld & outport[o].prdy;

      always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) l2_credit[o] <= '0;
        else          l2_credit[o] <= out_credit[o];
      end
    end
  endgenerate

  // Burst/credit qualification and build per-output request matrix
  always_comb begin
    for (int o=0;o<L2_NUM;o++) begin
      for (int i=0;i<L1_NUM;i++) begin
        // Request when input i wants output o
        logic req_i_o;
        req_i_o = l1_arb_array[i][o];

        // New start or continue burst
        logic continue_i;
        continue_i = l1_burst_active[i] && (l1_burst_l2_id[i] == o[PRI_WTH-1:0]);

        // Required credit: at least 1 for continue; new needs arb_len[i][o]
        logic [5:0] need;
        need = continue_i ? 6'd1 : {3'b000, l1_arb_len[i][o]};

        l2_req[o][i]   = (req_i_o | continue_i) && (l2_credit[o] > need);
      end
      l2_req_valid[o] = |l2_req[o];
    end
  end

  // Per-output RR arbitration with rotating priority
  generate
    for (genvar o=0;o<L2_NUM;o++) begin: g_rr
      rr_arbiter #(.N(L1_NUM), .W(PRI_WTH)) u_rr (
        .clk            (clk),
        .reset_n        (reset_n),
        .enq            (l2_req[o]),
        .pri            (l2_wheel),
        .winner_onehot  (l2_grant_oh[o]),
        .winner_valid   (l2_grant_vld[o]),
        .winner_encode  (l2_grant_idx[o])
      );
    end
  endgenerate

  // Feed grants back to inputs and update burst state
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      l1_wheel <= '0;
      l2_wheel <= '0;
      for (int i=0;i<L1_NUM;i++) begin
        l1_burst_active[i] <= 1'b0;
        l1_burst_cnt[i]    <= '0;
        l1_burst_l2_id[i]  <= '0;
        l1_win_vec[i]      <= '0;
      end
    end else begin
      // default no wins
      for (int i=0;i<L1_NUM;i++) l1_win_vec[i] <= '0;

      // collect per-output wins and translate to per-input win vectors
      for (int o=0;o<L2_NUM;o++) begin
        if (l2_grant_vld[o]) begin
          l1_win_vec[l2_grant_idx[o]][o] <= 1'b1;
        end
      end

      // update per-input burst trackers
      for (int i=0;i<L1_NUM;i++) begin
        // start new burst when won and not continuing
        logic new_win;
        new_win = |l1_win_vec[i];
        if (new_win && !l1_burst_active[i]) begin
          // choose the winning output index (only one bit set)
          logic [PRI_WTH-1:0] sel;
          sel = '0;
          for (int o=0;o<L2_NUM;o++) if (l1_win_vec[i][o]) sel = o[PRI_WTH-1:0];
          l1_burst_active[i] <= 1'b1;
          l1_burst_l2_id[i]  <= sel;
          l1_burst_cnt[i]    <= l1_grant_burst[i];
        end else if (l1_burst_active[i]) begin
          // decrement when we successfully enqueue a beat
          if (out_enq[l1_burst_l2_id[i]]) begin
            if (l1_burst_cnt[i] == 3'd1) begin
              l1_burst_active[i] <= 1'b0;
              l1_burst_cnt[i]    <= 3'd0;
            end else begin
              l1_burst_cnt[i]    <= l1_burst_cnt[i] - 3'd1;
            end
          end
        end
      end

      // rotate wheels each cycle (simple model)
      l1_wheel <= (l1_wheel == PRI_WTH'(L1_NUM-1)) ? '0 : (l1_wheel + 1'b1);
      l2_wheel <= (l2_wheel == PRI_WTH'(L2_NUM-1)) ? '0 : (l2_wheel + 1'b1);
    end
  end

  // Data path multiplexing from input i to output o when granted/continuing
  always_comb begin
    for (int o=0;o<L2_NUM;o++) begin
      out_enq[o]      = 1'b0;
      out_enq_data[o] = '0;
      for (int i=0;i<L1_NUM;i++) begin
        logic sel_i_o;
        sel_i_o = (l1_burst_active[i] && (l1_burst_l2_id[i] == o[PRI_WTH-1:0])) || l1_win_vec[i][o];
        if (sel_i_o && l1_data_vld_q[i]) begin
          out_enq[o]      = 1'b1;
          out_enq_data[o] = l1_data_q[i];
        end
      end
    end
  end

  // Debug export
  always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
      dbg_if.clk <= 1'b0;
      dbg_if.vld <= '0;
      dbg_if.sel <= '0;
    end else begin
      dbg_if.clk <= clk;
      for (int o=0;o<L2_NUM;o++) begin
        dbg_if.vld[o] <= out_enq[o];
        // select any i that enqueued to out o this cycle
        logic [PRI_WTH-1:0] sel;
        sel = '0;
        for (int i=0;i<L1_NUM;i++) begin
          logic sel_i_o;
          sel_i_o = (l1_burst_active[i] && (l1_burst_l2_id[i] == o[PRI_WTH-1:0])) || l1_win_vec[i][o];
          if (sel_i_o && l1_data_vld_q[i]) sel = i[PRI_WTH-1:0];
        end
        dbg_if.sel[o] <= sel;
      end
    end
  end

  // Status
  always_comb begin
    logic any_req, all_empty;
    any_req  = 1'b0;
    all_empty= 1'b1;
    for (int i=0;i<L1_NUM;i++) any_req |= |l1_arb_array[i];
    for (int o=0;o<L2_NUM;o++) all_empty &= out_empty[o];
    if (!any_req && all_empty)      dixbar_state = SP_STATUS_IDLE;
    else if (|out_empty == 1'b0)    dixbar_state = SP_STATUS_STALL; // simplistic
    else                            dixbar_state = SP_STATUS_ACTIVE;
  end

endmodule


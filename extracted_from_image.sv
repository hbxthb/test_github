// Transcribed from uploaded image (best effort). May need verification against the original source.

/////////////////////////////////////////////
// interface with input
/////////////////////////////////////////////

always_comb begin
  for (int l1_num = 0; l1_num < L1_NUM; l1_num = l1_num + 1) begin
    l1_arb_array[l1_num]         = arb_info[l1_num].req_array;
    l1_arb_length_array[l1_num]  = arb_info[l1_num].req_burst;
    l1_arb_info[l1_num]          = arb_info[l1_num];
    l2_arb_info[l1_num]          = arb_info[l1_num];
    l1_credit_release[l1_num]    = out_fifo_deq_rdy[l1_num];
  end
end

generate
  genvar l1_idx;
  for (l1_idx = 0; l1_idx < L1_NUM; l1_idx = l1_idx + 1) begin : input_grant
    assign grant_burst[l1_idx] = grant_burst_tag[l1_idx];
  end
endgenerate

/////////////////////////////////////////////
// flops for switch control
/////////////////////////////////////////////

always_ff @(posedge clk or negedge reset_) begin
  if (reset_ == 1'b0) begin
    // NOTE: Initial values inferred from image; widths may need confirmation
    l1_port_provided_iter <= '0;
    l1_wheel <= '0;   // width PRI_WIDTH assumed
    l2_wheel <= '0;   // width PRI_WIDTH assumed

    for (int l1_num = 0; l1_num < L1_NUM; l1_num = l1_num + 1) begin
      l1_grant_valid[l1_num] <= 1'b0;
      l1_burst_length[l1_num] <= '0; // 3'd0 in image
    end

    for (int l2_num = 0; l2_num < L2_NUM; l2_num = l2_num + 1) begin
      l2_credit[l2_num] <= '0;     // 6'd32 in image
      l2_credit_station[l2_num] <= '0; // 3'd0 in image
    end
  end else begin
    if (l1_port_provided_iter_update)
      l1_port_provided_iter <= l1_port_provided_iter_rot;

    if (pattern_arbiter_wheel) begin
      l1_wheel <= l1_wheel_rot;
      l2_wheel <= l2_wheel_rot;
    end

    // burst states
    for (int l1_num = 0; l1_num < L1_NUM; l1_num = l1_num + 1) begin
      if (l1_burst_len_update[l1_num])
        l1_burst_length[l1_num] <= l1_burst_length_rot[l1_num];
    end

    for (int l2_num = 0; l2_num < L2_NUM; l2_num = l2_num + 1) begin
      if (l2_credit_update[l2_num])
        l2_credit[l2_num] <= l2_credit_rot[l2_num];

      if (l2_credit_station_update[l2_num])
        l2_credit_station[l2_num] <= l2_credit_station_rot[l2_num];
    end
  end
end

always_ff @(posedge clk) begin
  for (int l1_num = 0; l1_num < L1_NUM; l1_num = l1_num + 1) begin
    if (l1_burst_l2_id_update[l1_num])
      l1_burst_l2_id[l1_num] <= l1_burst_l2_id_rot[l1_num];
  end
end

/////////////////////////////////////////////
// combinational logic for switch control
/////////////////////////////////////////////
// The remaining logic below this comment was not fully visible in the image.
// Please provide the complete source or a higher-resolution image to finish transcription exactly.


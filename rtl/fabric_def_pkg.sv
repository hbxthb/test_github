package fabric_def_pkg;

  // Request payload from initiator to xbar input adapter
  typedef struct packed {
    logic [2:0]  voq_id;        // target output index (0..7)
    logic [7:0]  req_id;        // request id within VOQ depth space
    logic [2:0]  burst_length;  // number of beats (1..8), encoded as length-1 in RTL where needed
  } req2xbar_t;

endpackage : fabric_def_pkg


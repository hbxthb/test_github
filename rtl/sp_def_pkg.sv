package sp_def_pkg;

  typedef enum logic [1:0] {
    SP_STATUS_IDLE   = 2'd0,
    SP_STATUS_STALL  = 2'd1,
    SP_STATUS_ACTIVE = 2'd2
  } sp_status_type_t;

endpackage : sp_def_pkg


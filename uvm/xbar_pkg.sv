package xbar_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import sp_def_pkg::*;
  import fabric_def_pkg::*;

  // Sequence item representing an input beat and VOQ meta
  class xbar_req extends uvm_sequence_item;
    rand bit [2:0]  voq_id;
    rand bit [7:0]  req_id;
    rand bit [2:0]  burst_len; // beats (1..8)
    rand bit [255:0] data;

    constraint c_burst { burst_len inside {[1:8]}; }

    `uvm_object_utils_begin(xbar_req)
      `uvm_field_int(voq_id,   UVM_ALL_ON)
      `uvm_field_int(req_id,   UVM_ALL_ON)
      `uvm_field_int(burst_len,UVM_ALL_ON)
      `uvm_field_int(data,     UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name = "xbar_req");
      super.new(name);
    endfunction
  endclass

  // Driver
  class xbar_driver extends uvm_driver#(xbar_req);
    uvm_analysis_port#(xbar_req) ap; // broadcast sent reqs
    virtual dixbar_inport_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual dixbar_inport_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "vif not set")
    endfunction
    task run_phase(uvm_phase phase);
      xbar_req tr;
      forever begin
        seq_item_port.get_next_item(tr);
        // drive one burst
        // send request header
        vif.req_pd.voq_id      <= tr.voq_id;
        vif.req_pd.req_id      <= tr.req_id;
        vif.req_pd.burst_length<= tr.burst_len;
        vif.req_valid          <= 1'b1;
        @(posedge vif.clk);
        // Data beats
        for (int b=0;b<tr.burst_len;b++) begin
          vif.data              <= tr.data ^ b;
          vif.data_valid        <= 1'b1;
          @(posedge vif.clk);
        end
        // deassert
        vif.req_valid   <= 1'b0;
        vif.data_valid  <= 1'b0;
        ap.write(tr);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class xbar_sequencer extends uvm_sequencer#(xbar_req);
    `uvm_component_utils(xbar_sequencer)
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
  endclass

  class xbar_agent extends uvm_component;
    `uvm_component_utils(xbar_agent)
    xbar_sequencer sqr;
    xbar_driver    drv;
    virtual dixbar_inport_if vif;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual dixbar_inport_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "vif not set")
      sqr = xbar_sequencer::type_id::create("sqr", this);
      drv = xbar_driver   ::type_id::create("drv", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      drv.vif = vif;
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // Monitor for outputs
  class xbar_out_tr extends uvm_sequence_item;
    bit [255:0] data;
    int         port_id;
    `uvm_object_utils_begin(xbar_out_tr)
      `uvm_field_int(data,   UVM_ALL_ON)
      `uvm_field_int(port_id,UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="xbar_out_tr"); super.new(name); endfunction
  endclass

  class xbar_out_monitor extends uvm_component;
    uvm_analysis_port#(xbar_out_tr) ap;
    virtual common_pipe_intf vifs[];
    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual common_pipe_intf[$])::get(this, "", "vifs", vifs))
        `uvm_fatal(get_type_name(), "vifs not set")
    endfunction
    task run_phase(uvm_phase phase);
      xbar_out_tr tr;
      forever begin
        for (int i=0;i<vifs.size();i++) begin
          if (vifs[i].pvld && vifs[i].prdy) begin
            tr = new(); tr.data = vifs[i].data; tr.port_id = i; ap.write(tr);
          end
        end
        #1ns;
      end
    endtask
  endclass

  // Input monitors (for data seen on in_if)
  class xbar_in_tr extends uvm_sequence_item;
    bit [255:0] data;
    int         in_id;
    `uvm_object_utils_begin(xbar_in_tr)
      `uvm_field_int(data,  UVM_ALL_ON)
      `uvm_field_int(in_id, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="xbar_in_tr"); super.new(name); endfunction
  endclass

  class xbar_in_monitor extends uvm_component;
    `uvm_component_utils(xbar_in_monitor)
    uvm_analysis_port#(xbar_in_tr) ap;
    virtual dixbar_inport_if vif;
    int in_id;
    function new(string name, uvm_component parent);
      super.new(name, parent); ap = new("ap", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual dixbar_inport_if)::get(this, "", "vif", vif))
        `uvm_fatal(get_type_name(), "vif not set")
      void'(uvm_config_int::get(this, "", "in_id", in_id));
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if (vif.data_valid) begin
          xbar_in_tr tr = new(); tr.data = vif.data; tr.in_id = in_id; ap.write(tr);
        end
      end
    endtask
  endclass

  // Debug interface monitor
  typedef struct packed { bit vld; int o; int i; } dbg_event_t;
  class xbar_dbg_monitor extends uvm_component;
    `uvm_component_utils(xbar_dbg_monitor)
    uvm_analysis_port#(dbg_event_t) ap;
    virtual xbar_dbg_if dbg_vif;
    function new(string name, uvm_component parent);
      super.new(name, parent); ap = new("ap", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual xbar_dbg_if)::get(this, "", "vif", dbg_vif))
        `uvm_fatal(get_type_name(), "dbg_vif not set")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge dbg_vif.clk);
        for (int o=0;o<dbg_vif.L2_NUM;o++) begin
          dbg_event_t ev; ev.o = o; ev.i = dbg_vif.sel[o]; ev.vld = dbg_vif.vld[o];
          if (ev.vld) ap.write(ev);
        end
      end
    endtask
  endclass

  // Simple scoreboard skeleton with reference model placeholder
  class xbar_scoreboard extends uvm_component;
    uvm_analysis_imp#(xbar_out_tr, xbar_scoreboard) out_imp;
    uvm_analysis_export#(xbar_in_tr)                in_exp;
    uvm_analysis_export#(dbg_event_t)               dbg_exp;

    // simple per-input last data snapshot
    bit [255:0] last_in_data[8];
    function new(string name, uvm_component parent);
      super.new(name, parent);
      out_imp = new("out_imp", this);
      in_exp  = new("in_exp");
      dbg_exp = new("dbg_exp");
    endfunction
    virtual function void write(xbar_out_tr t);
      `uvm_info(get_type_name(), $sformatf("Observed out%0d data=0x%0h", t.port_id, t.data), UVM_LOW)
      // TODO: compare with reference model expectations
    endfunction
    // analysis implementation for inputs and debug via TLM FIFOs
    uvm_tlm_analysis_fifo#(xbar_in_tr) in_fifo;
    uvm_tlm_analysis_fifo#(dbg_event_t) dbg_fifo;
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      in_fifo  = new("in_fifo", this);
      dbg_fifo = new("dbg_fifo", this);
      in_exp.connect(in_fifo.analysis_export);
      dbg_exp.connect(dbg_fifo.analysis_export);
    endfunction
    task run_phase(uvm_phase phase);
      fork
        forever begin
          xbar_in_tr it; in_fifo.get(it); last_in_data[it.in_id] = it.data;
        end
        forever begin
          dbg_event_t ev; dbg_fifo.get(ev);
          if (ev.vld) begin
            // when a mapping ev.i -> ev.o occurs, nothing to do here.
          end
        end
      join
    endtask
  endclass

  // Environment
  class xbar_env extends uvm_env;
    xbar_agent     agents[];
    xbar_out_monitor outm;
    xbar_scoreboard  scb;
    xbar_in_monitor  inmons[];
    xbar_dbg_monitor dbgmon;
    int IN_NUM;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_int::get(this, "", "IN_NUM", IN_NUM)) IN_NUM = 8;
      agents = new[IN_NUM];
      inmons = new[IN_NUM];
      for (int i=0;i<IN_NUM;i++) begin
        agents[i] = xbar_agent::type_id::create($sformatf("agent%0d", i), this);
        inmons[i] = xbar_in_monitor::type_id::create($sformatf("inmon%0d", i), this);
        uvm_config_int::set(this, inmons[i].get_full_name(), "in_id", i);
      end
      outm = xbar_out_monitor::type_id::create("outm", this);
      scb  = xbar_scoreboard::type_id::create("scb", this);
      dbgmon = xbar_dbg_monitor::type_id::create("dbgmon", this);
    endfunction
    virtual function void connect_phase(uvm_phase phase);
      outm.ap.connect(scb.out_imp);
      for (int i=0;i<IN_NUM;i++) begin
        inmons[i].ap.connect(scb.in_exp);
      end
      dbgmon.ap.connect(scb.dbg_exp);
    endfunction
  endclass

  // Base test
  class xbar_base_test extends uvm_test;
    xbar_env env;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      env = xbar_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      // Kick simple sequences on all agents
      foreach (env.agents[i]) begin
        xbar_req tr = xbar_req::type_id::create("tr");
        repeat (10) begin
          assert(tr.randomize());
          env.agents[i].sqr.start_item(tr);
          env.agents[i].sqr.finish_item(tr);
        end
      end
      #10000ns;
      phase.drop_objection(this);
    endtask
  endclass

endpackage


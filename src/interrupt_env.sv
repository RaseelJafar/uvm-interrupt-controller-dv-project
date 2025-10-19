class interrupt_env extends uvm_env;
  `uvm_component_utils(interrupt_env)

  irq_agent agent;
  irq_scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = irq_agent::type_id::create("agent", this);
    sb = irq_scoreboard::type_id::create("sb", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    agent.monitor.ap.connect(sb.imp);
  endfunction
endclass
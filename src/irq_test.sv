class irq_test extends uvm_test;
  `uvm_component_utils(irq_test)
  interrupt_env env;

  function new(string name="irq_test", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_top.set_report_verbosity_level_hier(UVM_LOW);
    env = interrupt_env::type_id::create("env", this);
  endfunction

  virtual function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
  endfunction

  task run_phase(uvm_phase phase);
    irq_sequence seq;
    phase.raise_objection(this);
      seq = irq_sequence::type_id::create("seq");
      seq.start(env.agent.sequencer);
      #100ns;
    phase.drop_objection(this);
  endtask
endclass

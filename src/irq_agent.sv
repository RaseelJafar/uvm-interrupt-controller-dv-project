class irq_agent extends uvm_agent;
  `uvm_component_utils(irq_agent)

  irq_driver driver;
  irq_monitor monitor;
  uvm_sequencer #(irq_transaction) sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sequencer = uvm_sequencer#(irq_transaction)::type_id::create("sequencer", this);
    driver = irq_driver::type_id::create("driver", this);
    monitor = irq_monitor::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

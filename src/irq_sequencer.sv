class irq_sequencer extends uvm_sequencer;
  `uvm_component_utils(irq_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

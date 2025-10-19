class irq_driver extends uvm_driver #(irq_transaction);
  `uvm_component_utils(irq_driver)

  virtual interrupt_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual interrupt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      irq_transaction tx;
      seq_item_port.get_next_item(tx);

      @(negedge vif.clk);
      vif.IRQ  <= tx.irq;
      vif.MASK <= tx.mask;
      vif.ACK  <= tx.ack;
      
      
      @(posedge vif.clk); 

      seq_item_port.item_done();
    end
  endtask
endclass
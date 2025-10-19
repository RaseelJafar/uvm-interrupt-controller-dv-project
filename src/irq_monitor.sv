class irq_monitor extends uvm_monitor;
  `uvm_component_utils(irq_monitor)

  virtual interrupt_if vif;
  uvm_analysis_port #(irq_transaction) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual interrupt_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "Virtual interface not found")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      irq_transaction tx = irq_transaction::type_id::create("tx", this);

      @(posedge vif.clk); #1;

      tx.rstn        = vif.rstn;
      tx.irq         = vif.IRQ;
      tx.mask        = vif.MASK;
      tx.ack         = vif.ACK;
      tx.obs_irq_out = vif.IRQ_OUT;
      tx.obs_irq_id  = vif.IRQ_ID;

      ap.write(tx);
    end
  endtask
endclass

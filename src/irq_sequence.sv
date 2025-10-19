class irq_sequence extends uvm_sequence;
  `uvm_object_utils(irq_sequence)

  function new(string name="irq_sequence"); super.new(name); endfunction

  virtual task body();
    irq_transaction tx;
    bit [7:0] prev_irq = '0;

    repeat (990) begin
      tx = irq_transaction::type_id::create($sformatf("tx_%0t", $time));
      start_item(tx);

      //randomize all fields
      assert(tx.randomize()) else `uvm_fatal("SEQ", "Randomize failed");

      tx.irq &= ~prev_irq;
      finish_item(tx);

      prev_irq = tx.irq;
    end
  endtask
endclass

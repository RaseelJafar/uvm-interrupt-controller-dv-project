class irq_transaction extends uvm_sequence_item;
  `uvm_object_utils(irq_transaction)

  // randomized stimuli
  rand bit [7:0] irq;
  rand bit [7:0] mask;
  rand bit       ack;
       bit       rstn;        

  // observed DUT outputs (from monitor)
       bit       obs_irq_out;
       bit [2:0] obs_irq_id;
  
  // Constructor
  function new(string name = "irq_transaction");
    super.new(name);
  endfunction

  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field_int("rstn", rstn, 1);  
    printer.print_field_int("irq",  irq,  8);
    printer.print_field_int("mask", mask, 8);
    printer.print_field_int("ack",  ack,  1);
    printer.print_field_int("obs_irq_out", obs_irq_out, 1);
    printer.print_field_int("obs_irq_id",  obs_irq_id,  3);
  endfunction
endclass

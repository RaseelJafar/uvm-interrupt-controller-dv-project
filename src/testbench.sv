`include "uvm_macros.svh"
import uvm_pkg::*;
`include "interrupt_if.sv"
`include "irq_transaction.sv"
`include "irq_sequence.sv"
`include "irq_sequencer.sv"
`include "irq_driver.sv"
`include "irq_monitor.sv"
`include "irq_scoreboard.sv"
`include "irq_agent.sv"
`include "interrupt_env.sv"
`include "irq_test.sv"

module testbench_top;
  bit clk;
  bit rstn;
  
  always #5 clk = ~clk;
  // Instantiate DUT interface
  interrupt_if intf(clk, rstn);
  // ===== Reset and Initialization Sequence =====
  initial begin
    clk  = 0;
    rstn = 0;
    intf.IRQ  = '0;
    intf.MASK = '0;
    intf.ACK  = 1'b0;
    #15 rstn = 1;
    // ---- Mid-run reset #1 
    #100 rstn = 0;  
    #20  rstn = 1;   
    // ---- Mid-run reset #2 
    #150 rstn = 0;
    #10  rstn = 1;
  end
  // ===== DUT Instantiation =====
  interrupt_controller dut (
    .clk    (clk),
    .rstn   (rstn),
    .IRQ    (intf.IRQ),
    .ACK    (intf.ACK),
    .MASK   (intf.MASK), 
    .IRQ_OUT(intf.IRQ_OUT),
    .IRQ_ID (intf.IRQ_ID)
  );
  // ===== UVM Testbench Initialization =====
  initial begin
    uvm_config_db#(virtual interrupt_if)::set(null, "*", "vif", intf);
    run_test("irq_test");
  end
endmodule

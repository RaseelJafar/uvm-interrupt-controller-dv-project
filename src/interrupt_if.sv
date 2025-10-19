interface interrupt_if(input bit clk, input bit rstn);
  logic [7:0] IRQ;
  logic [7:0] MASK;
  logic ACK;
  logic IRQ_OUT;
  logic [2:0] IRQ_ID;
endinterface

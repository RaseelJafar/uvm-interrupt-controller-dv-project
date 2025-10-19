module interrupt_controller (
  input  logic        clk,
  input  logic        rstn,
  input  logic [7:0]  IRQ,         
  input  logic        ACK,
  input  logic [7:0]  MASK,        
  output logic        IRQ_OUT,
  output logic [2:0]  IRQ_ID
);

  logic [7:0] pending_reg; 
  logic       ack_d1;       
  logic       out_r;         
  logic [2:0] id_r;          

  logic [7:0] next_pend;
  logic [7:0] eligible;
  logic       out_n;
  logic [2:0] id_n;

  // Priority encoder: choose lowest index '1' (bit0 highest priority)
  function automatic void prio_select(
    input  logic [7:0] elig,
    output logic       out,
    output logic [2:0] id
  );
    out = 1'b0; id = 3'd0;
    for (int i = 0; i < 8; i++) begin
      if (elig[i] && !out) begin
        out = 1'b1;
        id  = i[2:0];
      end
    end
  endfunction

  always_ff @(posedge clk) begin
    if (!rstn) begin
      pending_reg <= '0;
      ack_d1      <= 1'b0;
      out_r       <= 1'b0;
      id_r        <= 3'd0;
      IRQ_OUT     <= 1'b0;
      IRQ_ID      <= 3'd0;
    end else begin
      ack_d1 <= ACK;

      next_pend = pending_reg;
      if (ack_d1 && out_r) begin
        next_pend[id_r] = 1'b0;
      end

      next_pend |= IRQ;

      eligible = next_pend & ~MASK;

      prio_select(eligible, out_n, id_n);

      pending_reg <= next_pend;

      out_r <= out_n;
      if (out_n) begin
        id_r <= id_n;
      end

      IRQ_OUT <= out_n;
      IRQ_ID  <= out_n ? id_n : 3'd0;
    end
  end

endmodule

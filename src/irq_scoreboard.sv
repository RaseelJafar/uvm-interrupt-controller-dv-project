class irq_scoreboard extends uvm_component;
  `uvm_component_utils(irq_scoreboard)

  uvm_analysis_imp #(irq_transaction, irq_scoreboard) imp;

  // ===== Internal model state =====
  bit [7:0] pending_m;
  bit [7:0] mask_m;
  bit       prev_out;
  int       prev_id;
  bit       have_prev;
  bit       ack_d1;

  int unsigned cyc, match_count, mismatch_count;
  uvm_report_server m_svr;

  bit [7:0] pend_before, pend_after_ack, pend_after_or, eligible_bits;
  bit       exp_out_now;
  int       exp_id_now;
  int       clr_id;
  int       idx;

  bit just_released_reset;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    imp = new("imp", this);
     // Initialize internal state
    pending_m = '0; 
    mask_m = '0; 
    prev_out = 0; 
    prev_id = 0;
    have_prev = 0; 
    ack_d1 = 0; cyc = 0; 
    match_count = 0; 
    mismatch_count = 0;
    just_released_reset = 0;
  endfunction
  
  // Priority encoder model: pick lowest index active unmasked IRQ
  function void encode(input bit [7:0] pend, input bit [7:0] m,
                       output bit out, output int id);
    out = 0; id = 0;
    for (idx = 0; idx < 8; idx++) begin
      if (pend[idx] && !m[idx]) begin
        out = 1; id = idx; break;
      end
    end
  endfunction

  // Main scoreboard write method — compares DUT outputs to reference model
  task write(input irq_transaction tx);
    cyc++;

    // Handle reset: clear all model state when rstn=0
    if (!tx.rstn) begin
      pending_m  = '0;
      mask_m     = '0;
      prev_out   = 0;
      prev_id    = 0;
      have_prev  = 0;
      ack_d1     = 0;
      just_released_reset = 1;

      
      pend_before    = '0;
      pend_after_ack = '0;
      pend_after_or  = '0;
      eligible_bits  = '0;
      exp_out_now    = 0;
      exp_id_now     = 0;
      clr_id         = -1;

      `uvm_info("SCOREBOARD",
        $sformatf("Cycle : %0d | *** RESET ASSERTED *** | RSTN=%0b | Incoming IRQs=%b | Mask=%b | ACK=%0b | ModelCleared",
                  cyc, tx.rstn, tx.irq, tx.mask, tx.ack),
        UVM_NONE)
      return;
    end
    
    pend_before = pending_m;

    // apply pipelined ACK to clear previous ID
    clr_id = -1;
    if (ack_d1 && have_prev && prev_out) begin
      pending_m[prev_id] = 1'b0;
      clr_id = prev_id;
    end
    pend_after_ack = pending_m;

    // OR in new IRQs + update mask
    pending_m    |= tx.irq;
    mask_m        = tx.mask;
    pend_after_or = pending_m;

    // active & unmasked
    eligible_bits = pend_after_or & ~mask_m;

    //expected OUT/ID
    encode(pending_m, mask_m, exp_out_now, exp_id_now);

    // Compare DUT vs expected 
    if (!just_released_reset) begin
      if (tx.obs_irq_out !== exp_out_now ||
          (exp_out_now && tx.obs_irq_id !== exp_id_now[2:0])) begin
        mismatch_count++;
        `uvm_error("SCOREBOARD",
          $sformatf("Cycle : %0d  Mismatch: EXP(out=%0b,id=%0d) GOT(out=%0b,id=%0d)",
                    cyc, exp_out_now, exp_id_now, tx.obs_irq_out, tx.obs_irq_id))
      end else begin
        match_count++;
      end
    end
    else begin
      just_released_reset = 0;
    end


    `uvm_info("SCOREBOARD",
      $sformatf(
        "Cycle : %0d \n | RSTN=%0b | Incoming IRQs=%b | Mask=%b | Pending(before ACK)=%b | ACK=%0b  | Pending(after ACK)=%b |Pending(after new IRQs)=%b | Active & unmasked=%b | IRQ_OUT=%0b | IRQ_ID=%0d",
        cyc,
        1'b1,            
        tx.irq,
        tx.mask,
        pend_before,
        tx.ack,
        pend_after_ack,
        pend_after_or,
        eligible_bits,
        exp_out_now,
        exp_id_now
      ),
      UVM_NONE
    )

    prev_out  = exp_out_now;
    prev_id   = exp_id_now;
    have_prev = 1'b1;

    // ACK
    ack_d1    = tx.ack;
  endtask

  // Final test summary
  function void report_phase(uvm_phase phase);
    bit pass;
    m_svr = uvm_report_server::get_server();
    pass  = (m_svr.get_severity_count(UVM_FATAL) == 0) &&
            (m_svr.get_severity_count(UVM_ERROR) == 0) &&
            (mismatch_count == 0);

    `uvm_info(get_type_name(), "----------------------------------------", UVM_NONE)
    `uvm_info(get_type_name(),
      pass ? "-----------     TEST PASS     ----------"
           : "-----------     TEST FAIL     ----------",
      UVM_NONE)
    `uvm_info(get_type_name(),
      $sformatf("Cycles=%0d  Matches=%0d  Mismatches=%0d  UVM_ERROR=%0d UVM_FATAL=%0d",
                cyc, match_count, mismatch_count,
                m_svr.get_severity_count(UVM_ERROR),
                m_svr.get_severity_count(UVM_FATAL)), UVM_NONE)
    `uvm_info(get_type_name(), "----------------------------------------", UVM_NONE)
  endfunction
endclass

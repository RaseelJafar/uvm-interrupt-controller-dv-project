# Interrupt Controller — Design & Verification Using SystemVerilog/UVM

A complete RTL design and UVM-based verification environment for a simplified 8-input interrupt controller. The controller prioritizes interrupt requests from multiple peripherals, applies software-configurable masking, and signals the CPU with the ID of the highest-priority active interrupt. The verification achieved **zero mismatches across 1000 randomized regression cycles**.
  
> Authors: Raseel Jafar (1220724) · Yasmin Al Shawawrh (1220848)

---

## Table of contents

- [Design overview](#design-overview)
- [Port description](#port-description)
- [Internal architecture](#internal-architecture)
- [Testbench architecture](#testbench-architecture)
- [File structure](#file-structure)
- [Verification components](#verification-components)
- [Test sequences & test cases](#test-sequences--test-cases)
- [Golden reference model](#golden-reference-model)
- [Simulation results](#simulation-results)
---

## Design overview

The DUT (`interrupt_controller.sv`) is a synchronous 8-input interrupt controller that:
- Receives up to 8 simultaneous interrupt requests from peripherals (`IRQ[7:0]`)
- Latches pending requests into an internal **pending register**
- Filters pending requests through a software-configurable **mask register**
- Uses a **priority encoder** to select the highest-priority (lowest-index) active unmasked request
- Asserts `IRQ_OUT` and outputs the request ID on `IRQ_ID[2:0]` to the CPU
- Clears the served interrupt when the CPU asserts `ACK`
- Supports asynchronous active-low reset (`rstn`) that clears all internal state immediately

**Priority scheme:** IRQ0 = highest priority · IRQ7 = lowest priority  
**Mask bit semantics:** `1` = masked (disabled) · `0` = unmasked (enabled)

---

## Port description

| Port | Direction | Width | Description |
|---|---|---|---|
| `clk` | Input | 1 bit | System clock — all synchronous logic on rising edge |
| `rstn` | Input | 1 bit | Asynchronous active-low reset — clears pending register and all state |
| `IRQ[7:0]` | Input | 8 bits | Interrupt request lines — IRQ[0] has highest priority |
| `MASK[7:0]` | Input | 8 bits | Mask register — bit=1 disables the corresponding IRQ line |
| `ACK` | Input | 1 bit | CPU acknowledgment — clears the pending bit of the currently served interrupt |
| `IRQ_OUT` | Output | 1 bit | Global interrupt output — asserted when any unmasked pending interrupt exists |
| `IRQ_ID[2:0]` | Output | 3 bits | Encoded ID of the highest-priority active unmasked interrupt |

---

## Internal architecture

```
IRQ[7:0] ──→ [OR gate] ──→ Pending Register ──→ [AND with ~MASK] ──→ Priority Encoder ──→ IRQ_ID
                ↑                  ↑                                                      ↓
         Previous Pending    Cleared by ACK                                           IRQ_OUT
                             (one cycle delay)
                             Cleared by Rstn
```

**Pending register update logic (each clock cycle):**
1. Start with current `pending_reg`
2. If ACK received: clear the pending bit of the previously served interrupt
3. OR in new `IRQ` inputs — new requests are always latched
4. Apply mask: `eligible = pending & ~MASK`
5. Run `prio_select()` — find lowest-index set bit in eligible
6. Output `IRQ_OUT` and `IRQ_ID`

The `prio_select()` function iterates bits 0→7 and returns the first set bit, implementing strict fixed-priority arbitration.

---

## Testbench architecture

```
testbench_top
└── irq_test  (uvm_test)
    └── interrupt_env  (uvm_env)
        ├── irq_agent
        │   ├── irq_sequencer
        │   ├── irq_driver      ──→ drives IRQ, MASK, ACK on negedge clk
        │   └── irq_monitor     ──→ samples all signals on posedge clk + #1
        │         └── uvm_analysis_port
        │                  │
        └── irq_scoreboard  ←──────┘
            └── golden reference model (encode() function)
```

The monitor samples every posedge and sends a complete `irq_transaction` (inputs + observed outputs) to the scoreboard. The scoreboard runs the reference model each cycle and compares expected vs actual outputs.

---

## File structure

```
interrupt-controller-uvm/
├── rtl/
│   └── design.sv     # RTL design — pending reg, mask, priority encoder
└── tb/
    ├── interrupt_if.sv             # SystemVerilog interface (clk, rstn, IRQ, MASK, ACK, IRQ_OUT, IRQ_ID)
    ├── irq_transaction.sv          # UVM sequence item — rand irq, mask, ack; observed outputs
    ├── irq_sequence.sv             # Sequence — 20-cycle randomized stimulus, one-cycle IRQ pulses
    ├── irq_sequencer.sv            # UVM sequencer wrapper
    ├── irq_driver.sv               # Driver — drives on negedge, waits posedge, item_done()
    ├── irq_monitor.sv              # Monitor — samples posedge+#1, broadcasts irq_transaction
    ├── irq_scoreboard.sv           # Scoreboard + golden reference model + pass/fail report
    ├── irq_agent.sv                # Agent — integrates sequencer, driver, monitor
    ├── interrupt_env.sv            # Environment — agent + scoreboard, connects ap→imp
    ├── irq_test.sv                 # Top-level UVM test — creates env, starts sequence
    └── testbench_top.sv            # Simulation top — DUT, clock gen, reset, uvm_config_db, run_test
```

---

## Verification components

### Driver (`irq_driver.sv`)
Retrieves `irq_transaction` objects from the sequencer and drives `IRQ`, `MASK`, and `ACK` onto the DUT interface. Signals are updated on the **negative clock edge** and held stable through the positive edge to ensure proper DUT sampling.

### Monitor (`irq_monitor.sv`)
Passively observes all DUT signals on every **positive clock edge + #1ps** skew (for stability). Packages `rstn`, `IRQ`, `MASK`, `ACK`, `IRQ_OUT`, and `IRQ_ID` into an `irq_transaction` and broadcasts it via `uvm_analysis_port`.

### Scoreboard + Golden Reference Model (`irq_scoreboard.sv`)
The scoreboard contains the full golden reference model as an `encode()` function. Each cycle it:
1. Handles reset — clears all model state
2. Applies pipelined ACK — clears the pending bit of the previously served interrupt
3. OR's new IRQ inputs into the pending model
4. Applies mask filtering
5. Runs `encode()` to predict `IRQ_OUT` and `IRQ_ID`
6. Compares predictions against DUT outputs — any mismatch → `uvm_error`
7. Reports total matches, mismatches, UVM_ERROR count, and UVM_FATAL count in `report_phase`

### Sequence (`irq_sequence.sv`)
Generates 20 randomized `irq_transaction` items per run. Enforces **one-cycle IRQ pulse behavior** by masking off any bit that was set in the previous cycle (`tx.irq &= ~prev_irq`), preventing spurious re-assertion.

---

## Test sequences & test cases

| TC | Sequence | What is verified |
|---|---|---|
| TC1 | Basic Reset | Pending register and all outputs cleared to 0 after reset |
| TC2 | Single IRQ | `IRQ_OUT=1` and correct `IRQ_ID` for a single unmasked request |
| TC3 | Priority Resolution | Lowest-index active unmasked IRQ selected when multiple pending |
| TC4 | Mask Effect | Masked interrupt lines ignored even when pending |
| TC5 | ACK Clearing | Acknowledged interrupt cleared; next highest-priority interrupt promoted |
| TC6 | Randomized Regression | 1000 cycles of random IRQ/MASK/ACK — zero mismatches with reference model |

**Additional corner cases exercised:**
- Simultaneous ACK and new IRQ arriving in the same cycle
- All IRQs active simultaneously (IRQ[7:0] = 8'hFF)
- All IRQs masked (MASK = 8'hFF) — `IRQ_OUT` stays low
- Repeated interrupt from same line after clearing
- ACK with no active interrupt — no unexpected state change
- Mid-operation reset — all pending state cleared immediately

---

## Golden reference model

Implemented inside `irq_scoreboard` as a cycle-accurate software model tracking:

```systemverilog
bit [7:0] pending_m;   // model pending register
bit [7:0] mask_m;      // model mask register
bit       prev_out;    // last cycle's IRQ_OUT
bit [2:0] prev_id;     // last cycle's IRQ_ID
bit       ack_d1;      // pipelined ACK

// Each cycle:
if (ack_d1 && prev_out)   pending_m[prev_id] = 0;   // clear served interrupt
pending_m |= tx.irq;                                  // latch new requests
mask_m     = tx.mask;                                 // update mask
eligible   = pending_m & ~mask_m;                     // filter masked
encode(eligible, exp_out_now, exp_id_now);            // priority encode
```

The `encode()` function scans bits 0→7 and returns the first set bit — mirroring the RTL `prio_select()` function exactly.

---

## Simulation results

### Directed test highlights

| Cycle | Scenario | IRQ inputs | Mask | Active & unmasked | IRQ_OUT | IRQ_ID | Result |
|---|---|---|---|---|---|---|---|
| 1 | Reset | `00000000` | `00000000` | `00000000` | 0 | 0 | ✅ PASS |
| 2 | Single IRQ | `11010000` | `10100011` | `01010000` | 1 | 4 | ✅ PASS |
| 3 | Priority | `00100010` | `10111000` | `01000010` | 1 | 1 | ✅ PASS |
| 5 | All masked | `11111111` | `11111111` | `00000000` | 0 | 0 | ✅ PASS |
| 9 | Post-ACK | (IRQ0 cleared) | — | `10100000` | 1 | 5 | ✅ PASS |

### Regression result

```
Cycles=1000  Matches=993  Mismatches=0  UVM_ERROR=0  UVM_FATAL=0
TEST PASS
```

993 active cycles (7 in reset) — **zero mismatches** across all randomized IRQ, MASK, and ACK combinations.

---


// Top level testbench, so no need for ifndef guards.

`include "sv_build_example_includes.svh"

`include "pipeline.sv"

module pipeline_test_verilator
`ifdef VERILATOR
  (
   // Because Verilator is amazing, it needs clk and rst as module
   // inputs
  input wire clk,
  input wire rst,
   // I also include test_passed as a way to know my tb's main block
   // has actually completed and set this value to 1. You don't have
   // to do this on your flow, but I like it.
  output bit test_passed
   );
`else
  // Non-verilator, generate your own clocks, because event sim.
  ;
`endif

  initial begin : time_format
    $timeformat(-9, 3, "ns", 1);
  end


`ifndef VERILATOR
  // Non-Verilator testing: clk, rst, $assertoff/on control.
  logic clk, rst;
  bit test_passed = 1'b0;
  initial begin : clk_driver
    #0;
    clk = 1'b0;
    // If our main sets test_passed=1, then this will flush the event
    // queue, lets the test finish quickly if you don't like calling $finish.
    while (test_passed !== 1'b1) #1ns clk = ~clk;
  end

  initial begin : rst_driver
    #0;
    $assertoff;
    rst = 1'b0;

    repeat (3) @(posedge clk);
    rst = 1'b1;
    repeat (10) @(posedge clk);
    $asserton;
    repeat (1) @(posedge clk);
    rst = 1'b0;

  end
`else

  // Yes-Verilator testing: do nothing.

  // Our top level TB module(s) will be required to have
  // inputs clk, rst
  // output test_passed.


`endif // !`ifndef VERILATOR


  // Keep the cycle counter whether we're in Verilator or not, might come in
  // handy, IDK.
  int timeout_cycle = 1000;
  int cycle  /*verilator public */;
  always @(posedge clk) begin : cycle_counter
    if (rst) begin
      cycle <= 0;
    end else begin
      cycle <= cycle + 1'b1;
    end
  end


  // This module is too simple to really be randomizing
  // all parameter combinations.
  parameter int unsigned Width = 15;

`ifndef DEPTH
`define DEPTH 2
`endif

  parameter int  unsigned Depth = `DEPTH;

  logic [Width - 1 : 0] d;
  logic [Width - 1 : 0] dut_q;

  bit                   driver_enable = 0;
  bit                   sb_enable = 0;

  always @(posedge clk) begin
    if (rst || !driver_enable) begin
      d <= '0;
    end else begin
      d <= Width'($urandom);
    end
  end


  // An annoyance of Verilator is not being able to have a block like
  // initial begin : main
  // ...
  // end
  //
  // So instead, we have to think like designers and make a state machine.
  typedef enum int {
    kWaitReset,
    kInReset,
    kOutOfReset,
    kAutoStimulus1,
    kDone,
    kTestPassed
  } main_state_t;
  main_state_t main_state = kWaitReset;

  // main_state_counter is a relative cycle counter since the last state
  // arc. It helps b/c Verilator doesn't have wait statements.
  int            main_state_counter = 0;
`define _main_state_update(NextState) main_state_counter <= 0; main_state <= NextState

  always @(posedge clk) begin : main

    main_state_counter <= main_state_counter + 1'b1;

    case (main_state)

    kWaitReset: begin
      if (rst) begin
        test_passed <= 1'b0;
        `_main_state_update(kInReset);
      end
    end

    kInReset: begin
      // cycle will increment After reset
      if (rst == 0 && cycle >= 1) begin
        $display("%t %m: %s", $time,
                 $sformatf("start, Depth=%0d", Depth));
        $display("%t %m: %s", $time,
                 "out of rst");

        driver_enable <= 1'b1;
        sb_enable     <= 1'b1;
        `_main_state_update(kOutOfReset);
      end
    end

    kOutOfReset: begin
      `_main_state_update(kAutoStimulus1);
    end

    kAutoStimulus1: begin
      // This is the stimulus and checking state too,
      // just chill here for 100 cycles.
      if (main_state_counter >= 100) begin
        $display("%t %m: %s", $time,
                 "end");
        `_main_state_update(kDone);
      end
    end

    kDone: begin
        $display("%t %m: %s", $time,
                 "TEST_PASSED=1");
        test_passed <= 1'b1;
      `_main_state_update(kTestPassed);
    end

    kTestPassed: begin
      // Note - Verilator will want us to $finish
      $finish();
    end

    default: begin ; end
    endcase // case (main_state)

    if (cycle > timeout_cycle) begin
      test_passed <= 0;
      $error("%t %m: %s", $time,
             $sformatf("Test Timeout: cycle=%0d, timeout_cycle=%0d",
                       cycle, timeout_cycle));
      $finish();
    end

  end


  pipeline
    #(.Width(Width),
      .Depth(Depth)
      )
  u_dut
    (
     .clk,
     .d,
     .q(dut_q));

  generate
    if (Depth > 0) begin : gen_depth_gt0


      // Since I don't have Assert properties in Modelsim ASE or Verilator
      // I'll go overboard and check it with a queue, because it's an example.
      logic [Width - 1 : 0] dut_sb [$];
      always @(posedge clk) begin : scoreboard
        if (rst || !sb_enable) begin
          dut_sb.delete();
        end else begin

          if (dut_sb.size() == Depth) begin : MUST_dut_q__eq__dut_sb
            // Wait until our queue has Depth items in it.
            // Yeah we'll end up stranding the remaining Depth-1 items at the
            // end of test, but this is a simple example and the DUT forever
            // consuming its d input.

            // it's "full", so check dut_q vs dut_sb:
            assert(dut_sb[0] === dut_q);

            void'(dut_sb.pop_front());
          end

          dut_sb.push_back(d);

        end
      end

    end else begin : gen_depth0

      // We special check the Depth=0 case. Again, no assert property in
      // these simple simulators:
      always @(posedge clk) begin : Must_dut_depth0_d_eq_q
        assert (rst === 1'b1 || d === dut_q);
      end

    end
  endgenerate


  // Handle Verilator's amazing non-standard way of requiring $dumpfile and $dumpvars
  // if you actually want a wave.
  // This has to be used at the end of a Testbench module.
`ifdef VERILATOR
  initial begin : verilator_dump_wave
    if ($test$plusargs("trace")) begin
      automatic int trace = 0;
      $value$plusargs("trace=%0d", trace);
      if (trace) begin
        $display("%t: %m %s", $time,
                 $sformatf("Tracing to logs/vlt_dump.vcd trace=%0d", trace));
        $dumpfile("logs/vlt_dump.vcd");
        $dumpvars();
      end
    end
  end
`endif

endmodule : pipeline_test_verilator

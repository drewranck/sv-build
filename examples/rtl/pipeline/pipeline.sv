// pipeline.sv
// A pipeline with parametrizable number of stages

`ifndef pipeline__sv
`define pipeline__sv

`include "sv_build_example_includes.svh"

module pipeline
  #(
   parameter int unsigned Width = 1,
   parameter int unsigned Depth = 1
    )
  (
  input                        clk,

  input [Width - 1 : 0]        d,
  output logic [Width - 1 : 0] q
   );

  // To map cleanly to an SRL, potentially, we'd want to push into
  // index [0], and pop from index [Depth - 1]
  // This is done via a macro because why not, it's an example!

  generate
    if (Depth == 0) begin : gen_wires
      assign q = d;
    end else begin : gen_stages
      `SRL_PIPELINE(clk, d, q, int_q, Width, Depth)
    end
  endgenerate

  `undef _LOCAL_PIPELINE

endmodule : pipeline

`endif

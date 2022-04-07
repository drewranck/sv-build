
`ifndef sv_build_example_srl_defines__svh
`define sv_build_example_srl_defines__svh

  // SRL(clk, d, q, load, rdptr, memq, Width, Depth)
  //   args:
  //     clk: clock
  //     d: D/scan-in input
  //     q: output at rdptr
  //     load: write enable bit for 'd'
  //     rdptr: read index
  //     memq: internal variable (flops) for q, gets attribute(s)
  //            applied.
  //     Width, Depth: width of vector, stages in pipeline
  //
  //   returns: none, this is SystemVerilog (returns code!)
  //
  //  - declares memq (must be first thing in macro so attributes
  //    apply!)
  //  - assigns memq, assigns q.

`ifndef SRL
`define SRL(Clk, D, Q, Load, RdPtr, MemQ, Width, Depth) \
  logic [(Depth) - 1 : 0] [(Width) - 1 : 0] MemQ; \
  always_ff @(posedge (Clk)) begin \
    if (Load) begin \
      for (int i = (Depth) - 1; i > 0; i--) begin \
        ``MemQ``[i] <= ``MemQ``[i - 1]; \
      end \
      ``MemQ``[0] <= D; \
    end \
  end \
  assign Q  = ``MemQ``[RdPtr];
`endif


  // SRL_PIPELINE(clk, d, q, memq, Width, Depth)
  //   args:
  //     clk: clock
  //     d: D/scan-in input
  //     q: output at rdptr
  //     memq: internal variable (flops) for q, gets attribute(s)
  //            applied.
  //     Width, Depth: width of vector, stages in pipeline
  //
  //   returns: none, this is SystemVerilog (returns code!)
  //
  //  - declares memq (must be first thing in macro so attributes
  //    apply!)
  //  - assigns memq, assigns q.
  //  - always reads from tail (Depth-1), always loads.
`ifndef SRL_PIPELINE
`define SRL_PIPELINE(Clk, D, Q, MemQ, Width, Depth) \
  `SRL(Clk, D, Q, 1'b1, \
       Depth - 1, MemQ, \
       Width, Depth)
`endif



`endif //  `ifndef sv_build_example_srl_defines__svh

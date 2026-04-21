// ----------------------------------------------------------------------------
// skew_injector.sv — Parallel skew shift register chain.
//   Stream i is delayed by exactly i cycles before reaching dout[i].
//   Implementation uses a single 2D register [r][s] declared at module scope
//   (more portable across older iverilog than per-generate arrays).
//   Unused SR cells (s >= r) are constant 0 and are stripped by synthesis.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module skew_injector #(
    parameter int DATA_WIDTH = 8,
    parameter int N          = 8
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              en,
    // Packed 2D ports — iverilog 13 silently propagates X across unpacked
    // array ports (both 1D and 2D), so keep every inter-module array port
    // packed. Internal storage stays unpacked so the procedural shift
    // register (runtime loop variables) is legal.
    input  wire  signed [N-1:0][DATA_WIDTH-1:0] din,
    output logic signed [N-1:0][DATA_WIDTH-1:0] dout
);

    // Unpack din at the boundary using genvars (constant indices only).
    logic signed [DATA_WIDTH-1:0] din_u [N];
    genvar gi;
    generate
        for (gi = 0; gi < N; gi++) begin : g_in
            assign din_u[gi] = din[gi];
        end
    endgenerate

    // sr[r][s] is stage s of stream r's delay chain. Stream r uses sr[r][0..r-1].
    logic signed [DATA_WIDTH-1:0] sr [N][N];

    integer r, s;
    always_ff @(posedge clk) begin
        if (rst) begin
            for (r = 0; r < N; r = r + 1)
                for (s = 0; s < N; s = s + 1)
                    sr[r][s] <= '0;
        end else if (en) begin
            for (r = 0; r < N; r = r + 1) begin
                sr[r][0] <= din_u[r];
                for (s = 1; s < N; s = s + 1)
                    sr[r][s] <= sr[r][s-1];
            end
        end
    end

    // Drive packed output via generate; each element uses a constant index.
    genvar gr;
    generate
        for (gr = 0; gr < N; gr++) begin : g_out
            if (gr == 0) assign dout[gr] = din_u[gr];
            else         assign dout[gr] = sr[gr][gr-1];
        end
    endgenerate

endmodule

`default_nettype wire

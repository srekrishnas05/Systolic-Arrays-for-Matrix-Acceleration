// ----------------------------------------------------------------------------
// pe.sv — Processing Element
//   acc += A_in * B_in (signed)
//   Registers A_in -> A_out and B_in -> B_out (pipeline wave in both axes)
//   Per-PE accumulator, synchronous clear via acc_clr
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module pe #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32
) (
    input  wire                              clk,
    input  wire                              rst,
    input  wire                              en,
    input  wire                              acc_clr,
    input  wire signed [DATA_WIDTH-1:0]      A_in,
    input  wire signed [DATA_WIDTH-1:0]      B_in,
    output logic signed [DATA_WIDTH-1:0]     A_out,
    output logic signed [DATA_WIDTH-1:0]     B_out,
    output logic signed [ACC_WIDTH-1:0]      C_out
);

    logic signed [ACC_WIDTH-1:0]  acc_q;
    logic signed [DATA_WIDTH-1:0] a_q, b_q;

    always_ff @(posedge clk) begin
        if (rst) begin
            a_q   <= '0;
            b_q   <= '0;
            acc_q <= '0;
        end else begin
            a_q <= A_in;
            b_q <= B_in;
            if (acc_clr)
                acc_q <= '0;
            else if (en)
                acc_q <= acc_q + $signed(A_in) * $signed(B_in);
        end
    end

    assign A_out = a_q;
    assign B_out = b_q;
    assign C_out = acc_q;

endmodule

`default_nettype wire

// ----------------------------------------------------------------------------
// systolic_array.sv — SIZE x SIZE grid of PEs
//   A flows west -> east, B flows north -> south.
//   Each PE maintains its own C[i][j] accumulator (output stationary).
//   Caller is responsible for skewing inputs on both edges.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module systolic_array #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int SIZE       = 8
) (
    input  wire                           clk,
    input  wire                           rst,
    input  wire                           en,
    input  wire                           acc_clr,
    // Packed 2D inputs and packed 3D output — iverilog 13 silently drops
    // values passed through unpacked-array ports, so every port is packed.
    input  wire  signed [SIZE-1:0][DATA_WIDTH-1:0]         A_west,
    input  wire  signed [SIZE-1:0][DATA_WIDTH-1:0]         B_north,
    output logic signed [SIZE-1:0][SIZE-1:0][ACC_WIDTH-1:0] C_out
);

    // Horizontal A bus: a_h[r][0..SIZE], vertical B bus: b_v[0..SIZE][c]
    logic signed [DATA_WIDTH-1:0] a_h [SIZE][SIZE+1];
    logic signed [DATA_WIDTH-1:0] b_v [SIZE+1][SIZE];

    genvar r, c;
    generate
        for (r = 0; r < SIZE; r++) begin : g_west
            assign a_h[r][0] = A_west[r];
        end
        for (c = 0; c < SIZE; c++) begin : g_north
            assign b_v[0][c] = B_north[c];
        end

        for (r = 0; r < SIZE; r++) begin : g_row
            for (c = 0; c < SIZE; c++) begin : g_col
                pe #(
                    .DATA_WIDTH(DATA_WIDTH),
                    .ACC_WIDTH (ACC_WIDTH)
                ) u_pe (
                    .clk    (clk),
                    .rst    (rst),
                    .en     (en),
                    .acc_clr(acc_clr),
                    .A_in   (a_h[r][c]),
                    .B_in   (b_v[r][c]),
                    .A_out  (a_h[r][c+1]),
                    .B_out  (b_v[r+1][c]),
                    .C_out  (C_out[r][c])
                );
            end
        end
    endgenerate

endmodule

`default_nettype wire

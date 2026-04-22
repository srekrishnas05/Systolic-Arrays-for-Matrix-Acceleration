// ----------------------------------------------------------------------------
// tiling_controller.sv — Decomposes MxK * KxN into 8x8 inner tiles.
//   For each output tile (i, j) iterate k = 0..ceil(K/SIZE)-1, issuing a
//   tile_start pulse to the inner FSM and waiting for tile_done. `accumulate`
//   is high for all k>0 of a given (i,j) so the PE accumulators keep adding
//   rather than clearing. Zero-padding of edge tiles is the producer's job.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module tiling_controller #(
    parameter int SIZE      = 8,
    parameter int DIM_WIDTH = 16
) (
    input  wire                        clk,
    input  wire                        rst,
    input  wire                        go,
    input  wire  [DIM_WIDTH-1:0]       M,
    input  wire  [DIM_WIDTH-1:0]       N,
    input  wire  [DIM_WIDTH-1:0]       K,

    input  wire                        tile_done,
    output logic                       tile_start,
    output logic [DIM_WIDTH-1:0]       tile_i,
    output logic [DIM_WIDTH-1:0]       tile_j,
    output logic [DIM_WIDTH-1:0]       tile_k,
    output logic                       accumulate,
    output logic                       all_done
);

    typedef enum logic [1:0] {T_IDLE, T_ISSUE, T_WAIT, T_DONE} tstate_t;
    tstate_t tstate;

    logic [DIM_WIDTH-1:0] tiles_M, tiles_N, tiles_K;
    assign tiles_M = (M + SIZE - 1) / SIZE;
    assign tiles_N = (N + SIZE - 1) / SIZE;
    assign tiles_K = (K + SIZE - 1) / SIZE;

    always_ff @(posedge clk) begin
        if (rst) begin
            tstate <= T_IDLE;
            tile_i <= '0;
            tile_j <= '0;
            tile_k <= '0;
        end else begin
            unique case (tstate)
                T_IDLE: if (go) begin
                    tstate <= T_ISSUE;
                    tile_i <= '0;
                    tile_j <= '0;
                    tile_k <= '0;
                end
                T_ISSUE: tstate <= T_WAIT;
                T_WAIT:  if (tile_done) begin
                    if (tile_k + 1 < tiles_K) begin
                        tile_k <= tile_k + 1'b1;
                        tstate <= T_ISSUE;
                    end else if (tile_j + 1 < tiles_N) begin
                        tile_k <= '0;
                        tile_j <= tile_j + 1'b1;
                        tstate <= T_ISSUE;
                    end else if (tile_i + 1 < tiles_M) begin
                        tile_k <= '0;
                        tile_j <= '0;
                        tile_i <= tile_i + 1'b1;
                        tstate <= T_ISSUE;
                    end else begin
                        tstate <= T_DONE;
                    end
                end
                T_DONE:  tstate <= T_IDLE;
                default: tstate <= T_IDLE;
            endcase
        end
    end

    assign tile_start = (tstate == T_ISSUE);
    assign accumulate = (tile_k != '0);
    assign all_done   = (tstate == T_DONE);

endmodule

`default_nettype wire

// ----------------------------------------------------------------------------
// accelerator_top.sv — 8x8 matmul accelerator for a single tile.
//   Wires the FSM, two skew injectors, and the systolic array together.
//   Tile operand ports (A_tile, B_tile, C_tile) are packed 3D arrays so that
//   they cross module boundaries cleanly in iverilog 13 — unpacked 2D ports
//   silently propagate as X in that simulator version.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module accelerator_top #(
    parameter int DATA_WIDTH = 8,
    parameter int ACC_WIDTH  = 32,
    parameter int SIZE       = 8
) (
    input  wire                                                clk,
    input  wire                                                rst,
    input  wire                                                start,

    // Tile operands — packed 3D for portable port semantics.
    input  wire  signed [SIZE-1:0][SIZE-1:0][DATA_WIDTH-1:0]   A_tile,
    input  wire  signed [SIZE-1:0][SIZE-1:0][DATA_WIDTH-1:0]   B_tile,
    output logic signed [SIZE-1:0][SIZE-1:0][ACC_WIDTH-1:0]    C_tile,
    output logic                                               done
);

    // ------------------------------------------------------------------ FSM
    logic acc_clr, stream_en, pe_en, store, swap;
    logic [$clog2(SIZE)-1:0] stream_idx;
    logic [2:0] state_dbg;

    controller_fsm #(.SIZE(SIZE)) u_fsm (
        .clk(clk), .rst(rst), .start(start),
        .acc_clr(acc_clr), .stream_en(stream_en), .pe_en(pe_en),
        .stream_idx(stream_idx),
        .store(store), .swap(swap), .done(done),
        .state_dbg(state_dbg)
    );

    // ------------------------------------------------------- Streaming mux
    // When stream_en is high, present one column of A and one row of B per
    // cycle, selected by stream_idx (0..SIZE-1). Otherwise present zeros so
    // the skew pipeline is flushed with harmless data.
    //
    // iverilog 13 rejects variable indices into packed arrays inside
    // procedural blocks, so first unpack A_tile/B_tile into unpacked 2D
    // mirrors using a generate block (constant indices). Then the streaming
    // mux only indexes unpacked arrays with runtime variables, which works.
    logic signed [DATA_WIDTH-1:0] A_up [SIZE][SIZE];
    logic signed [DATA_WIDTH-1:0] B_up [SIZE][SIZE];

    genvar ur, uc;
    generate
        for (ur = 0; ur < SIZE; ur++) begin : g_unpack_r
            for (uc = 0; uc < SIZE; uc++) begin : g_unpack_c
                assign A_up[ur][uc] = A_tile[ur][uc];
                assign B_up[ur][uc] = B_tile[ur][uc];
            end
        end
    endgenerate

    // Packed 2D streaming and skew wires — must be packed to feed
    // skew_injector and systolic_array (which now use packed array ports
    // throughout to dodge iverilog 13's unpacked-port propagation bug).
    logic signed [SIZE-1:0][DATA_WIDTH-1:0] a_stream;
    logic signed [SIZE-1:0][DATA_WIDTH-1:0] b_stream;
    logic signed [SIZE-1:0][DATA_WIDTH-1:0] a_skewed;
    logic signed [SIZE-1:0][DATA_WIDTH-1:0] b_skewed;

    // Use generate+continuous-assign instead of always_comb: iverilog 13
    // cannot infer a sensitivity list for a procedural block that indexes
    // an unpacked 2D array with a runtime variable, so the block evaluates
    // only once at time 0 and every C output ends up as X. Continuous
    // assigns are always live and sidestep sensitivity inference. Each
    // target slice (a_stream[gsi]) uses a genvar, i.e. an elaboration-time
    // constant, which iverilog handles correctly on packed arrays.
    genvar gsi, gsj;
    generate
        for (gsi = 0; gsi < SIZE; gsi++) begin : g_astream
            assign a_stream[gsi] = stream_en ? A_up[gsi][stream_idx]
                                             : {DATA_WIDTH{1'b0}};
        end
        for (gsj = 0; gsj < SIZE; gsj++) begin : g_bstream
            assign b_stream[gsj] = stream_en ? B_up[stream_idx][gsj]
                                             : {DATA_WIDTH{1'b0}};
        end
    endgenerate

    skew_injector #(.DATA_WIDTH(DATA_WIDTH), .N(SIZE)) u_skew_a (
        .clk(clk), .rst(rst), .en(1'b1),
        .din(a_stream), .dout(a_skewed)
    );
    skew_injector #(.DATA_WIDTH(DATA_WIDTH), .N(SIZE)) u_skew_b (
        .clk(clk), .rst(rst), .en(1'b1),
        .din(b_stream), .dout(b_skewed)
    );

    // ------------------------------------------------------ Systolic array
    // C_raw is packed 3D to match the systolic_array output port and to
    // avoid any unpacked-array port propagation issues.
    logic signed [SIZE-1:0][SIZE-1:0][ACC_WIDTH-1:0] C_raw;

    systolic_array #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .SIZE      (SIZE)
    ) u_array (
        .clk    (clk),
        .rst    (rst),
        .en     (pe_en),
        .acc_clr(acc_clr),
        .A_west (a_skewed),
        .B_north(b_skewed),
        .C_out  (C_raw)
    );

    // ------------------------------------------------------------ C latch
    // Latch accumulator values during STORE so the user-visible C_tile is
    // stable while the next tile begins. Packed arrays permit whole-array
    // non-blocking assignment.
    always_ff @(posedge clk) begin
        if (rst)          C_tile <= '0;
        else if (store)   C_tile <= C_raw;
    end

    // swap is surfaced on the FSM for external ping-pong logic; unused here.
    wire _unused = swap;

endmodule

`default_nettype wire

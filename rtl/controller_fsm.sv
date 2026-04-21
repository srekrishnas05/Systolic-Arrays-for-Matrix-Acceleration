// ----------------------------------------------------------------------------
// controller_fsm.sv — Top-level control for a single 8x8 tile.
//   States: IDLE -> LOAD_SKEW -> COMPUTE -> DRAIN -> STORE -> IDLE
//     LOAD_SKEW : SIZE cycles  — clear accumulators, prime skew pipelines
//     COMPUTE   : SIZE cycles  — drive A columns and B rows into the array
//     DRAIN     : 2*SIZE-2     — let the last skewed values propagate
//     STORE     : SIZE cycles  — latch C outputs, signal swap/done
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module controller_fsm #(
    parameter int SIZE = 8
) (
    input  wire  clk,
    input  wire  rst,
    input  wire  start,

    output logic acc_clr,        // assert in LOAD_SKEW to clear accumulators
    output logic stream_en,      // assert in COMPUTE to push data into skew
    output logic pe_en,          // assert while PEs should accumulate
    output logic [$clog2(SIZE)-1:0] stream_idx, // 0..SIZE-1 column/row index
    output logic store,          // assert in STORE to latch C
    output logic swap,           // 1-cycle pulse at end of STORE
    output logic done,           // 1-cycle pulse at end of STORE
    output logic [2:0] state_dbg
);

    typedef enum logic [2:0] {
        S_IDLE      = 3'd0,
        S_LOAD_SKEW = 3'd1,
        S_COMPUTE   = 3'd2,
        S_DRAIN     = 3'd3,
        S_STORE     = 3'd4
    } state_t;

    state_t state, nstate;

    localparam int LOAD_CYC    = SIZE;
    localparam int COMPUTE_CYC = SIZE;
    localparam int DRAIN_CYC   = 2*SIZE - 1;   // enough for all skew + PE regs
    localparam int STORE_CYC   = SIZE;

    logic [7:0] cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            cnt   <= '0;
        end else begin
            if (state != nstate) cnt <= '0;
            else                 cnt <= cnt + 8'd1;
            state <= nstate;
        end
    end

    always_comb begin
        nstate = state;
        unique case (state)
            S_IDLE:      if (start)                       nstate = S_LOAD_SKEW;
            S_LOAD_SKEW: if (cnt == LOAD_CYC    - 1)      nstate = S_COMPUTE;
            S_COMPUTE:   if (cnt == COMPUTE_CYC - 1)      nstate = S_DRAIN;
            S_DRAIN:     if (cnt == DRAIN_CYC   - 1)      nstate = S_STORE;
            S_STORE:     if (cnt == STORE_CYC   - 1)      nstate = S_IDLE;
            default:                                       nstate = S_IDLE;
        endcase
    end

    always_comb begin
        acc_clr    = (state == S_LOAD_SKEW);
        stream_en  = (state == S_COMPUTE);
        pe_en      = (state == S_COMPUTE) || (state == S_DRAIN);
        store      = (state == S_STORE);
        swap       = (state == S_STORE) && (cnt == STORE_CYC - 1);
        done       = (state == S_STORE) && (cnt == STORE_CYC - 1);
        state_dbg  = state;
    end

    // Constant bit-selects inside always_* trip up iverilog 13 ("sorry:
    // constant selects in always_* processes are not currently supported").
    // Keep this one out here as a continuous assign so it works everywhere.
    assign stream_idx = cnt[$clog2(SIZE)-1:0];

endmodule

`default_nettype wire

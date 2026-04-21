// ----------------------------------------------------------------------------
// ping_pong_buffer.sv — Double-buffered BRAM pair.
//   While one bank is being read for COMPUTE, the other is being loaded with
//   the next tile. The `swap` pulse (driven by the FSM at end of STORE)
//   toggles which bank is the read side vs. the write side.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module ping_pong_buffer #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 1024,
    parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  wire                       clk,
    input  wire                       rst,
    input  wire                       swap,

    // Producer side (writes into the "shadow" bank).
    input  wire                       we,
    input  wire [ADDR_WIDTH-1:0]      waddr,
    input  wire [DATA_WIDTH-1:0]      wdata,

    // Consumer side (reads the active bank).
    input  wire [ADDR_WIDTH-1:0]      raddr,
    output logic [DATA_WIDTH-1:0]     rdata
);

    // bank_sel=0: bank0 active (read), bank1 shadow (write)
    // bank_sel=1: bank1 active (read), bank0 shadow (write)
    logic bank_sel;

    always_ff @(posedge clk) begin
        if (rst)       bank_sel <= 1'b0;
        else if (swap) bank_sel <= ~bank_sel;
    end

    logic [DATA_WIDTH-1:0] dout0, dout1;
    wire we0 = we &  bank_sel;
    wire we1 = we & ~bank_sel;

    bram_controller #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_bank0 (
        .clk(clk), .wea(we0), .addra(waddr), .dina(wdata),
        .addrb(raddr), .doutb(dout0)
    );
    bram_controller #(.DATA_WIDTH(DATA_WIDTH), .DEPTH(DEPTH)) u_bank1 (
        .clk(clk), .wea(we1), .addra(waddr), .dina(wdata),
        .addrb(raddr), .doutb(dout1)
    );

    assign rdata = bank_sel ? dout1 : dout0;

endmodule

`default_nettype wire

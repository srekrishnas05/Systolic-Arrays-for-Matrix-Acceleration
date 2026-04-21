// ----------------------------------------------------------------------------
// bram_controller.sv — Simple dual-port synchronous RAM.
//   Port A: write-only (wea/addra/dina).
//   Port B: read-only, registered output (addrb/doutb).
//   ram_style attribute hints block RAM; synthesis will infer RAMB36/18 on
//   Xilinx and equivalent primitives on other FPGAs.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps
`default_nettype none

module bram_controller #(
    parameter int DATA_WIDTH = 8,
    parameter int DEPTH      = 1024,
    parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
    input  wire                       clk,

    input  wire                       wea,
    input  wire [ADDR_WIDTH-1:0]      addra,
    input  wire [DATA_WIDTH-1:0]      dina,

    input  wire [ADDR_WIDTH-1:0]      addrb,
    output logic [DATA_WIDTH-1:0]     doutb
);

    (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [DEPTH];

    always_ff @(posedge clk) begin
        if (wea) mem[addra] <= dina;
        doutb <= mem[addrb];
    end

endmodule

`default_nettype wire

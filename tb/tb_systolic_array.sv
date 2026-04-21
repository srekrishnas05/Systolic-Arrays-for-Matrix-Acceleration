// ----------------------------------------------------------------------------
// tb_systolic_array.sv — Self-checking testbench for the 8x8 accelerator.
//   Runs:
//     1) Identity * random
//     2) All-ones * all-ones
//     3) Zeros * random
//     4) 100 randomized INT8 matmuls
//   Compares each C against a plain nested-loop reference and reports
//   PASS/FAIL with element indices.
// ----------------------------------------------------------------------------
`timescale 1ns/1ps

module tb_systolic_array;

    localparam int DATA_WIDTH = 8;
    localparam int ACC_WIDTH  = 32;
    localparam int SIZE       = 8;

    // --------------------------------------------------------------- clock
    logic clk = 1'b0;
    always #5 clk = ~clk;  // 100 MHz

    // --------------------------------------------------------------- ports
    logic rst;
    logic start;
    logic done;

    // Storage is unpacked 2D so procedural loops (variable indices) work in
    // iverilog 13. We bridge to packed 3D only at the DUT port, using a
    // generate/genvar copy so no procedural variable indices touch the
    // packed array.
    logic signed [DATA_WIDTH-1:0] A     [SIZE][SIZE];
    logic signed [DATA_WIDTH-1:0] B     [SIZE][SIZE];
    logic signed [ACC_WIDTH-1:0]  C     [SIZE][SIZE];
    logic signed [ACC_WIDTH-1:0]  C_ref [SIZE][SIZE];

    // Packed 3D bridge wires for DUT port connection.
    logic signed [SIZE-1:0][SIZE-1:0][DATA_WIDTH-1:0] A_pk;
    logic signed [SIZE-1:0][SIZE-1:0][DATA_WIDTH-1:0] B_pk;
    logic signed [SIZE-1:0][SIZE-1:0][ACC_WIDTH-1:0]  C_pk;

    genvar gr, gc;
    generate
        for (gr = 0; gr < SIZE; gr++) begin : g_pack
            for (gc = 0; gc < SIZE; gc++) begin : g_pack_c
                assign A_pk[gr][gc] = A[gr][gc];
                assign B_pk[gr][gc] = B[gr][gc];
                assign C[gr][gc]    = C_pk[gr][gc];
            end
        end
    endgenerate

    accelerator_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .ACC_WIDTH (ACC_WIDTH),
        .SIZE      (SIZE)
    ) dut (
        .clk    (clk),
        .rst    (rst),
        .start  (start),
        .A_tile (A_pk),
        .B_tile (B_pk),
        .C_tile (C_pk),
        .done   (done)
    );

    // ------------------------------------------------------ reference model
    task automatic compute_ref();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                longint acc;
                acc = 0;
                for (int k = 0; k < SIZE; k++) begin
                    acc += longint'($signed(A[i][k])) * longint'($signed(B[k][j]));
                end
                // Assign longint to narrower packed slot — implicit low-bits
                // truncation, avoids constant bit-selects that iverilog 13
                // rejects inside procedural blocks.
                C_ref[i][j] = acc;
            end
        end
    endtask

    int total_errors = 0;
    int total_tests  = 0;

    task automatic run_one(input string label);
        int err;
        err = 0;
        total_tests++;

        compute_ref();

        @(posedge clk);
        start <= 1'b1;
        @(posedge clk);
        start <= 1'b0;

        // Wait for done pulse
        do @(posedge clk); while (!done);
        // `done` is 1 at end-of-STORE; C_tile register latches during STORE.
        // Give it one more cycle so the captured value is stable.
        @(posedge clk);

        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                if (C[i][j] !== C_ref[i][j]) begin
                    err++;
                    if (err <= 4) begin
                        $display("  FAIL [%s] C[%0d][%0d] expected=%0d actual=%0d",
                                 label, i, j, C_ref[i][j], C[i][j]);
                    end
                end
            end
        end

        if (err == 0) $display("  PASS [%s]", label);
        else          $display("  FAIL [%s] %0d mismatches", label, err);
        total_errors += err;
    endtask

    task automatic fill_identity_random();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                A[i][j] = (i == j) ? 8'sd1 : 8'sd0;
                B[i][j] = $signed($random) % 8'sd100;
            end
        end
    endtask

    task automatic fill_ones();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                A[i][j] = 8'sd1;
                B[i][j] = 8'sd1;
            end
        end
    endtask

    task automatic fill_zeros_random();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                A[i][j] = 8'sd0;
                B[i][j] = $signed($random);
            end
        end
    endtask

    task automatic fill_random();
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                A[i][j] = $signed($random);
                B[i][j] = $signed($random);
            end
        end
    endtask

    // ----------------------------------------------------------- stimulus
    initial begin
        // init
        rst   = 1'b1;
        start = 1'b0;
        for (int i = 0; i < SIZE; i++) begin
            for (int j = 0; j < SIZE; j++) begin
                A[i][j] = '0;
                B[i][j] = '0;
            end
        end

        repeat (4) @(posedge clk);
        rst <= 1'b0;
        @(posedge clk);

        $display("=== TB: identity * random ===");
        fill_identity_random();
        run_one("identity");

        $display("=== TB: all-ones * all-ones ===");
        fill_ones();
        run_one("ones");

        $display("=== TB: zeros * random ===");
        fill_zeros_random();
        run_one("zeros");

        $display("=== TB: 100 random INT8 trials ===");
        for (int t = 0; t < 100; t++) begin
            fill_random();
            run_one($sformatf("rand_%0d", t));
        end

        $display("");
        if (total_errors == 0) begin
            $display("================================================");
            $display("  ALL %0d TESTS PASSED", total_tests);
            $display("================================================");
        end else begin
            $display("================================================");
            $display("  %0d ERRORS across %0d tests", total_errors, total_tests);
            $display("================================================");
        end

        $finish;
    end

    // safety timeout
    initial begin
        #2000000;
        $display("TIMEOUT");
        $finish;
    end

endmodule

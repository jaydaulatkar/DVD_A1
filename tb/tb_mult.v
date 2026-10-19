// -----------------------------------------------------------------------------
// tb_mult.v
// Exhaustive, self-checking testbench for mult_array.
//
//   * 10 ns clock (100 MHz), rst_n held low for the first 2 clock cycles
//   * applies all 256 combinations a = 0..15, b = 0..15
//   * inputs are applied on the falling edge, so they are stable before
//     clock edge 1 (captured into a_r/b_r) and the product is captured into p
//     at clock edge 2; p is checked on the following falling edge
//   * prints one line per mismatch and exactly one PASS/FAIL summary line
//   * writes the waveform file mult.vcd
// Works for both the RTL and the synthesized gate-level netlist.
// -----------------------------------------------------------------------------
`timescale 1ns / 1ps

module tb_mult;

    reg        clk;
    reg        rst_n;
    reg  [3:0] a;
    reg  [3:0] b;
    wire [7:0] p;

    integer    ia, ib;
    integer    errors;
    integer    vectors;
    reg  [7:0] expected;

    // device under test
    mult_array dut (
        .clk  (clk),
        .rst_n(rst_n),
        .a    (a),
        .b    (b),
        .p    (p)
    );

    // 10 ns clock period
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // waveform dump
    initial begin
        $dumpfile("mult.vcd");
        $dumpvars(0, tb_mult);
    end

    initial begin
        errors  = 0;
        vectors = 0;
        a       = 4'd0;
        b       = 4'd0;

        // hold reset low for the first 2 clock cycles (edges at 5 ns and 15 ns)
        rst_n = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        for (ia = 0; ia < 16; ia = ia + 1) begin
            for (ib = 0; ib < 16; ib = ib + 1) begin
                // apply the inputs (we are on a falling edge here)
                a        = ia[3:0];
                b        = ib[3:0];
                expected = ia * ib;      // '*' allowed in the testbench only

                // 2-cycle latency: edge 1 captures a/b, edge 2 captures p
                @(posedge clk);
                @(posedge clk);
                @(negedge clk);          // sample half a cycle after edge 2

                vectors = vectors + 1;
                if (p !== expected) begin
                    errors = errors + 1;
                    $display("MISMATCH at %0t ns: a=%0d b=%0d expected=%0d got=%0d",
                             $time, ia, ib, expected, p);
                end
            end
        end

        if (errors == 0)
            $display("PASS: %0d vectors checked, %0d errors", vectors, errors);
        else
            $display("FAIL: %0d vectors checked, %0d errors", vectors, errors);

        $finish;
    end

endmodule

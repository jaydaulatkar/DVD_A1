// -----------------------------------------------------------------------------
// mult_array.v
// 4-bit x 4-bit unsigned array multiplier with registered inputs and output.
//
//   * a and b are captured into 4-bit registers (a_r, b_r) on every rising edge
//   * the array (16 AND gates + 12 full adders) is built from a_r / b_r
//   * the 8-bit product is captured into p on the next rising edge
//   => 16 flip-flops, latency = 2 clock cycles, throughput = 1 result / cycle
//
// The '*' operator is NOT used. Connections follow the "Exact connections"
// table of the assignment (Section 2):
//
//   pp_i[j] = a_r[j] & b_r[i]
//   row 0 : p[0] = pp0[0];          r0 = {0,     pp0[3], pp0[2], pp0[1]}
//   row 1 : FA(pp1[j], r0[j], c1[j]) -> s1[j], c1[j+1];  c1[0] = 0
//           p[1] = s1[0];           r1 = {c1[4], s1[3],  s1[2],  s1[1]}
//   row 2 : FA(pp2[j], r1[j], c2[j]) -> s2[j], c2[j+1];  c2[0] = 0
//           p[2] = s2[0];           r2 = {c2[4], s2[3],  s2[2],  s2[1]}
//   row 3 : FA(pp3[j], r2[j], c3[j]) -> s3[j], c3[j+1];  c3[0] = 0
//           p[3] = s3[0];           p[7:4] = {c3[4], s3[3], s3[2], s3[1]}
// -----------------------------------------------------------------------------
module mult_array (
    input  wire       clk,    // clock, rising edge
    input  wire       rst_n,  // asynchronous reset, active low
    input  wire [3:0] a,      // multiplicand
    input  wire [3:0] b,      // multiplier
    output reg  [7:0] p       // product a x b, registered
);

    // ---------------------------------------------------------------- inputs
    reg [3:0] a_r;
    reg [3:0] b_r;

    // ------------------------------------------------- partial products (16 AND)
    wire [3:0] pp0 = a_r & {4{b_r[0]}};
    wire [3:0] pp1 = a_r & {4{b_r[1]}};
    wire [3:0] pp2 = a_r & {4{b_r[2]}};
    wire [3:0] pp3 = a_r & {4{b_r[3]}};

    // --------------------------------------------------------------- row 0
    wire [3:0] r0 = {1'b0, pp0[3], pp0[2], pp0[1]};

    // ---------------------------------------------------- rows 1..3 (12 FAs)
    wire [3:0] s1, s2, s3;          // sum outputs of each adder row
    wire [4:0] c1, c2, c3;          // carry chain of each adder row
    wire [3:0] r1, r2;              // bits passed down to the next row

    assign c1[0] = 1'b0;
    assign c2[0] = 1'b0;
    assign c3[0] = 1'b0;

    genvar j;
    generate
        for (j = 0; j < 4; j = j + 1) begin : row1
            full_adder fa (
                .a   (pp1[j]),
                .b   (r0[j]),
                .cin (c1[j]),
                .sum (s1[j]),
                .cout(c1[j+1])
            );
        end
    endgenerate

    assign r1 = {c1[4], s1[3], s1[2], s1[1]};

    generate
        for (j = 0; j < 4; j = j + 1) begin : row2
            full_adder fa (
                .a   (pp2[j]),
                .b   (r1[j]),
                .cin (c2[j]),
                .sum (s2[j]),
                .cout(c2[j+1])
            );
        end
    endgenerate

    assign r2 = {c2[4], s2[3], s2[2], s2[1]};

    generate
        for (j = 0; j < 4; j = j + 1) begin : row3
            full_adder fa (
                .a   (pp3[j]),
                .b   (r2[j]),
                .cin (c3[j]),
                .sum (s3[j]),
                .cout(c3[j+1])
            );
        end
    endgenerate

    // ------------------------------------------------------ combinational product
    wire [7:0] p_next = {c3[4], s3[3], s3[2], s3[1],   // p[7:4]
                         s3[0],                        // p[3]
                         s2[0],                        // p[2]
                         s1[0],                        // p[1]
                         pp0[0]};                      // p[0]

    // ------------------------------------------------------------ registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_r <= 4'd0;
            b_r <= 4'd0;
            p   <= 8'd0;
        end else begin
            a_r <= a;
            b_r <= b;
            p   <= p_next;
        end
    end

endmodule

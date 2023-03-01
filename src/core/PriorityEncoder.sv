`include "../typedefs.svh"


// BIT_WIDTH must be >= 1
module PriorityEncoder #(
    BIT_WIDTH
) (
    input wire [BIT_WIDTH - 1:0] b,
    output w8 lsb,
    output wire zero
);
    localparam M = BIT_WIDTH / 2;
    generate
        if (BIT_WIDTH == 1) begin
            assign lsb = 0;
            assign zero = ~b[0];
        end else begin
            w8 lower_lsb;
            wire lower_zero;
            PriorityEncoder #(M) p_l (
                .b(b[M - 1:0]), .lsb(lower_lsb), .zero(lower_zero)
            );
            w8 higher_lsb;
            wire higher_zero;
            PriorityEncoder #(BIT_WIDTH - M) p_h (
                .b(b[BIT_WIDTH - 1:M]), .lsb(higher_lsb), .zero(higher_zero)
            );

            assign lsb = (lower_zero) ? higher_lsb + M : lower_lsb;
            assign zero = lower_zero & higher_zero;
        end
    endgenerate
endmodule
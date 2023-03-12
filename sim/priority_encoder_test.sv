module priority_encoder_test;
    wire [7:0] b = 'b10000000;
    wire [7:0] lsb;
    wire zero;
    PriorityEncoder #(8) encoder (
        .b, .lsb, .zero
    );
    always @*
        $display("%0h, %0h", lsb, zero);
endmodule
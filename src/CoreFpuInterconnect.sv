module CoreFpuInterconnect (
    input wire clock,
    input wire reset,

    IFpu.slave request
);
    // stall中にval1, val2が保存されるようにする
    reg [31:0] val1_saved;
    reg [31:0] val2_saved;
    always_ff @(posedge clock) begin
        if (reset) begin
            val1_saved <= 32'h3f800000;
            val2_saved <= 32'h3f800000;
        end else if (request.en) begin
            val1_saved <= request.val1;
            val2_saved <= request.val2;
        end
    end

    wire valid, idle;
    wire [31:0] x1 = (request.en) ? request.val1 : val1_saved;
    wire [31:0] x2 = (request.en) ? request.val2 : val2_saved;
    fpu fpu_i(
        .clk(clock), .bram_clk(clock), .funct(request.funct), .x1, .x2,
        .y(request.result), .en(request.en), .valid, .idle
    );

    assign request.stall = ~idle;
endmodule
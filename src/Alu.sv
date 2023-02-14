module Alu (
    input wire en,
    input wire imm,
    input wire mov,
    input wire [3:0] funct,
    input wire [7:0] src1,
    input wire [7:0] src2,
    input wire [31:0] read1,
    input wire [31:0] read2,
    input wire [31:0] read_dest,

    output wire [31:0] result  // en=0のときは0
);
    wire [31:0] add = (funct[0]) ? read1 + read2 : 0;
    wire [31:0] sub = (funct[1]) ? read1 - read2 : 0;
    wire [31:0] fabs = (funct[2]) ? {1'b0, read2[30:0]} : 0;
    wire [31:0] fneg = (funct[3]) ? {~read2[31], read2[30:0]} : 0;
    wire [31:0] result_reg = add | sub | fabs | fneg;

    wire [31:0] ext8 = {24'd0, src2};
    wire [31:0] addi = (funct[0]) ? read1 + ext8 : 0;
    wire [31:0] subi = (funct[1]) ? read1 - ext8 : 0;
    wire [31:0] slli = (funct[2]) ? read1 << ext8 : 0;
    wire [31:0] result_imm = addi | subi | slli;

    wire [31:0] movl = (funct[0]) ? {16'd0, src1, src2} : 0;
    wire [31:0] movh = (funct[1]) ? {src1, src2, read_dest[15:0]} : 0;
    wire [31:0] result_mov = movl | movh;

    assign result = (~en ? 0 : (~imm ? result_reg : (mov ? result_mov : result_imm)));
endmodule
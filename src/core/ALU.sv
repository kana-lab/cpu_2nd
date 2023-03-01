`include "../typedefs.svh"
`include "bus.svh"


module ALU (
    input AluInstr alu_instr,
    output Result result
);
    w32 src1, src2;
    assign src1 = alu_instr.src1.content.data;
    assign src2 = alu_instr.src2.content.data;

    w32 addsub, slli, fabsfneg, mov, ans;
    assign addsub = (alu_instr.funct3[0]) ? src1 - src2 : src1 + src2;
    assign slli = src1 << src2;
    assign fabsfneg = (alu_instr.funct3[0]) ? {~src2[31], src2[30:0]} : {1'b0, src2[30:0]};
    assign mov = (alu_instr.funct3[0]) ? {src1[15:0], src2[15:0]} : src1;
    assign ans =
        (alu_instr.aux_op[0]) ?
            (alu_instr.funct3[2] ? mov : fabsfneg) : 
            (alu_instr.funct3[1] ? slli : addsub);
    
    assign result.commit_id = alu_instr.commit_id;
    assign result.kind = 0;
    assign result.content.wb.dest_phys = alu_instr.dest_phys;
    assign result.content.wb.dest_logic = alu_instr.dest_logic;
    assign result.content.wb.data = ans;
endmodule
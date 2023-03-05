`include "../typedefs.svh"
`include "bus.svh"


module fless(
    input logic [31:0] x1,
    input logic [31:0] x2,
    output logic [31:0] y
    // output logic idle,
    // input logic clk
);
    wire [7:0] e1;
    wire [22:0] m1;
    wire  s1;

    logic bool_y;

    assign e1 = x1[30:23];
    assign m1 = x1[22:0];
    assign s1 = x1[31];

    wire [7:0] e2;
    wire [22:0] m2;
    wire  s2;

    assign e2 = x2[30:23];
    assign m2 = x2[22:0];
    assign s2 = x2[31];
    assign bool_y = (s1==1'b0) ? ((s2==1'b0) ? ((e1==e2) ? (m1 < m2) : (e1 < e2))  : 1'b0)
                : ((s2 == 1'b0) ? 1'b1 : ((e1==e2) ? (m1 > m2) : (e1 > e2)));
    assign y = {31'b0, bool_y};
    // assign idle = 1'b1;
endmodule

module BranchUnit (
    input BranchInstr branch_instr,
    output Result result
);
    w32 read1, read2;
    assign read1 = branch_instr.src1.content.data;
    assign read2 = branch_instr.src2.content.data;
    wire [2:0] funct = branch_instr.funct3;

    w32 flt;
    fless fless(.x1(read1), .x2(read2), .y(flt));
    wire eq = (read1 == read2) ? 'b1 : 'b0;
    
    wire ibeq = (funct == 3'd0) ? eq : 1'b0;
    wire ibne = (funct == 3'd1) ? (read1 != read2 ? 1'b1 : 1'b0) : 1'b0;
    wire iblt = (funct == 3'd2) ? (read1 < read2 ? 1'b1 : 1'b0) : 1'b0;
    wire ible = (funct == 3'd3) ? (read1 <= read2 ? 1'b1 : 1'b0) : 1'b0;
    wire fblt = (funct == 3'd4) ? flt : 1'b0;
    wire fble = (funct == 3'd5) ? (flt[0] | eq) : 1'b0;
    wire fbps = (funct == 3'd6) ? ~read2[31] : 1'b0;
    wire fbng = (funct == 3'd7) ? read2[31] : 1'b0;
    wire taken = (ibeq | ibne | iblt | ible | fblt | fble | fbps | fbng);

    assign result.commit_id = branch_instr.commit_id;
    assign result.kind = 'b1;
    assign result.content.branch.taken = taken | branch_instr.jr;
    assign result.content.branch.miss = (taken ^ branch_instr.approx) | branch_instr.jr;
    assign result.content.branch.new_pc = (branch_instr.jr) ? read2 : branch_instr.new_pc;
endmodule
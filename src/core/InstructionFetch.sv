`include "../typedefs.svh"
    
module is_offset_jump (
    input w32 instr,
    input w32 pc,
    output wire yes,
    output w32 jump_addr
);
    assign yes = instr[31] & instr[30] & instr[27] & instr[29];
    w32 offset;
    assign offset = (instr[23]) ? {16'hffff, instr[23:8]} : {16'd0, instr[23:8]};
    assign jump_addr = pc + offset;
endmodule

module is_branch (
    input w32 instr,
    input w32 pc,
    output wire yes,
    output w32 branch_addr
);
    assign yes = instr[31] & ~instr[30];
    w32 offset;
    assign offset = (instr[26]) ? {21'h1fffff, instr[26:16]} : {21'd0, instr[26:16]};
    assign branch_addr = pc + offset;
endmodule

module prioritize (
    input wire force_jump,
    input w32 jump_addr,
    input wire approx,
    input w32 branch_addr,
    input wire flash,
    input w32 flash_addr,
    input wire stall,
    input w32 pc,
    output w32 new_pc
);
    assign new_pc =
        (flash) ? flash_addr : (
        (stall) ? pc : (
        (force_jump) ? jump_addr : (
        (approx) ? branch_addr : 
            (pc + 'd1))));
endmodule


module InstructionFetch (
    input wire clock,
    input wire reset,
    input wire stall,
    // ハードウェア割り込みはひとまず実装しない
    // リターンアドレススタックを持つjal/jrがあったら楽なんだけど…
    // input wire flash,
    // input w32 flash_addr,

    input BranchResult branch_result,
    IInstr.master instr_mem,

    output w32 instr_out,
    output w32 pc_out,
    output wire approx_out
);
    localparam nop = 32'hf0000000;
    localparam R_ret = 8'd253;

    r32 pc;  // 32bit確保はするが、実際は下位15bitのみ使用する
    w32 instr;
    assign instr = instr_mem.instr;

    // 無条件ジャンプの検出
    wire force_jump;
    w32 jump_addr;
    is_offset_jump is_offset_jump(.instr, .pc, .yes(force_jump), .jump_addr);

    // 分岐の検出 & 分岐予測
    IPredictor pred();
    assign pred.pred_pc = pc[14:0];
    assign pred.rslt_en = branch_result.en;
    assign pred.rslt_pc = branch_result.current_pc;
    assign pred.rslt_taken = branch_result.taken;
    w32 branch_addr;
    is_branch is_branch(.instr, .pc, .yes(pred.pred_en), .branch_addr);
    GSharePredictor gshare(.clk(clock), .predict(pred.slave));

    // プログラムカウンタの更新
    // flash > stall > jump > branch
    w32 new_pc;
    wire flash = branch_result.en & branch_result.miss;
    prioritize prioritize(
        .force_jump, .jump_addr, .approx(pred.pred_taken), .branch_addr,
        .flash, .flash_addr(branch_result.jump_addr), .stall, .pc, .new_pc
    );

    // output
    assign instr_mem.addr = new_pc;
    w32 inc_pc;
    assign inc_pc = pc + 'd1;
    w32 movl_pc;
    assign movl_pc = {8'h1c, inc_pc[15:0], R_ret};
    assign instr_out =
        (reset | flash) ? nop : (
        (~force_jump) ? instr : (
        (instr[24]) ? movl_pc :
            nop));
    assign pc_out = pc;
    assign approx_out = pred.pred_taken;

    always_ff @(posedge clock) begin
        if (reset) begin
            pc <= 0;
        end else begin
            pc <= new_pc;
        end
    end
endmodule
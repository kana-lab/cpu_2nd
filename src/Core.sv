module IFStage (
    input wire clock,
    input wire reset,
    input wire stall,

    // 分岐用 (EX stageのBranch Unitから飛んでくる)
    input wire pred_failed,
    input wire [31:0] new_pc,

    // GShare Predictor用
    input wire gshare_taken,
    input wire [31:0] proposed_pc,

    // 命令メモリ用
    IInstr.master instr_mem,

    // ID stageへの出力
    output wire [31:0] instruction,  // instructionの面倒はみない
    output reg [31:0] prev_pc,
    output reg approximation  // 1:taken, 0:untakenと予想
);
    localparam nop = 32'hf0000000;

    // なんとプログラムカウンタはワイヤー！
    wire [31:0] pc;
    always_comb begin
        if (reset | stall) begin
            pc = prev_pc;
        end else if (pred_failed) begin
            pc = new_pc;
        end else if (gshare_taken) begin
            pc = proposed_pc;
        end else begin
            pc = prev_pc + 32'd1;
        end
    end
    
    assign instr_mem.addr = pc;
    assign instruction = instr_mem.instr;

    always_ff @(posedge clock) begin
        if (reset) begin
            prev_pc <= 0;
        end else begin
            prev_pc <= pc;
        end
    end
endmodule


module IDStage (
    input wire clock,
    input wire reset,
    input wire stall,

    // IFStageからの入力
    input wire [31:0] instruction,
    input wire [31:0] pc,
    input wire approximation

    // GShare Predictorへの出力
    output wire pred_en,
    output wire [31:0] pred_pc,
    output wire [31:0] proposed_pc,  // IF stage用

    // 無条件ジャンプ用
    output wire force_jmp,
    output wire [31:0] jmp_pc,

    // ライトバック用の入力
    input wire wb_enable,
    input wire [7:0] wb_dest,
    input wire [31:0] wb_val,

    // ID stageの出力
    IAluInput.master alu,
    IFpuInput.master fpu,
    IBuInput.master bu,
    IDevice.master device,

    output reg [31:0] dest_reg,
    output reg jr_en,
    output reg [31:0] jr_addr
);
    // instructionをパーツに分解
    wire [2:0] op;
    wire [4:0] funct;
    wire [7:0] dest;
    wire [7:0] src1;
    wire [7:0] src2;
    assign {op, funct, dest, src1, src2} = instruction;

    assign pred_en = op[2] & ~op[1];
    assign pred_pc = pc;
    wire [31:0] offset_ext = (instruction[26]) ? {22'h3fffff, instruction[25:16]} : {22'h0, instruction[25:16]};
    assign proposed_pc = pc + offset_ext;

    assign force_jmp = op[2] & op[1] & ~op[0] & ~funct[1];
    wire [31:0] imm15_ext = (instruction[15]) ? {16'hffff, instruction[15:0]} : {16'b0, instruction[15:0]};
    assign jmp_pc = pc + imm15_ext;

    // レジスタファイルの定義
    reg [31:0] reg_file[255:0];

    // 読み出し & フォールスルー
    wire [31:0] read1 = (src1 == 8'hff) ? 0 : ((src1 == wb_dest) ? wb_val : reg_file[src1]);
    wire [31:0] read2 = (src2 == 8'hff) ? 0 : ((src2 == wb_dest) ? wb_val : reg_file[src2]);
    wire [31:0] read_dest = (dest == wb_dest) ? wb_val : reg_file[dest];

    // write back
    always_ff @(posedge clock) begin : blockName
        if (wb_enable) begin
            reg_file[wb_dest] <= wb_val;
        end
    end

    always_ff @(posedge clock) begin
        if (reset | ((&op) & funct[4])) begin
            alu.en <= 0;
            fpu.en <= 0;
            bu.en <= 0;
            device.en <= 0;
            device.wb <= 0;
            jr_en <= 0;
        end else if (~stall) begin
            dest_reg <= dest;
            jr_addr <= read2;
            jr_en <= op[2] & op[1] & ~op[0] & funct[1];

            alu.en <= ~(op[2] | op[1]);
            alu.imm <= op[0];
            alu.mov <= funct[4];
            alu.funct <= funct[3:0];
            alu.src1 <= src1;
            alu.src2 <= src2;
            alu.read1 <= read1;
            alu.read2 <= read2;
            alu.read_dest <= read_dest;

            fpu.en <= (op == 3'b010) ? 1'b1 : 1'b0;
            fpu.funct <= funct;
            fpu.val1 <= read1;
            fpu.val2 <= read2;

            bu.en <= op[2] & ~op[1];
            bu.funct <= instruction[29:27];
            bu.jump_addr <= proposed_pc;
            bu.read1 <= read1;
            bu.read2 <= read2;

            device.en <= op[1] & op[0];
            device.wb <= ~op[2];
            device.uart <= ~funct[0];
            device.neg <= funct[1];
            device.addr <= read2;
            device.offset <= (op[2]) ? dest : src1;
            device.val <= read1;
        end
    end    
endmodule


module EX_MEMStage (

);
endmodule


module Core (
    input wire clock,
    input wire reset,

    IInstr.master instr_mem,
    ICache.master cache,
    ISendRequest.master io_send,
    IRecvRequest.master io_recv
);
    
endmodule
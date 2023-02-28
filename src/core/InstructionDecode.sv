`include "../typedefs.svh"
`include "bus.svh"


module process_read_data (
    input w32 instr,
    input Source read1,
    input Source read2,
    output Source processed1,
    output Source processed2
);
    wire always_valid1 = instr[28] & ~(instr[31] & ~instr[30]) | (instr[29] & instr[28]);
    wire always_valid2 = instr[29] & ~(instr[31] & ~instr[30]);
    always_comb begin
        processed1.valid = read1.valid | always_valid1;
        if (always_valid1) begin
            processed1.content.data = {16'h0, instr[23:8]};
        end else begin
            processed1.content = read1.content;
        end

        processed2.valid = read2.valid | always_valid2;
        if (always_valid2) begin
            processed2.content.data = {24'h0, instr[7:0]};
        end else begin
            processed2.content = read2.content;
        end
    end
endmodule

module decode_alu_instr (
    input wire flash,
    input w32 instr,
    input w64 dest_phys,
    input Source src1,
    input Source src2,
    input w8 commit_id,
    output wire alu_en,
    output AluInstr alu_instr
);
    assign alu_en = (instr[31:30] == 'b00 && instr[27]) ? ~flash : 0;

    assign alu_instr.commit_id = commit_id;
    assign alu_instr.aux_op = instr[29:28];
    assign alu_instr.funct3 = instr[26:24];
    assign alu_instr.dest_logic = (
        instr[31:30] == 'b00 && instr[27:26] == 'b11
    ) ? instr[7:0] : instr[23:16];
    assign alu_instr.dest_phys = dest_phys;
    assign alu_instr.src1 = src1;
    assign alu_instr.src2 = src2;
endmodule

module decode_fpu_instr (
    input wire flash,
    input w32 instr,
    input w64 dest_phys,
    input Source src1,
    input Source src2,
    input w8 commit_id,
    output wire fpu_en,
    output FpuInstr fpu_instr
);
    assign fpu_en = (instr[31:30] == 'b01) ? ~flash : 0;
    
    assign fpu_instr.commit_id = commit_id;
    assign fpu_instr.funct5 = instr[28:24];
    assign fpu_instr.dest_logic = instr[23:16];
    assign fpu_instr.dest_phys = dest_phys;
    assign fpu_instr.src1 = src1;
    assign fpu_instr.src2 = src2;
endmodule

module decode_bu_instr (
    input wire flash,
    input w32 instr,
    input wire approx,
    input w16 pc,
    input Source src1,
    input Source src2,
    input w8 commit_id,
    output wire bu_en,
    output BranchInstr bu_instr
);
    assign bu_en = (instr[31:30] == 'b10 || bu_instr.jr) ? ~flash : 0;

    assign bu_instr.commit_id = commit_id;
    assign bu_instr.jr = instr[31] & instr[30] & instr[27];
    assign bu_instr.approx = approx;
    assign bu_instr.funct3 = instr[29:27];
    w16 offset;
    assign offset = (instr[26]) ? {5'h1f, instr[26:16]} : {5'h0, instr[26:16]};
    assign bu_instr.new_pc = pc + offset;
    assign bu_instr.src1 = src1;
    assign bu_instr.src2 = src2;
endmodule

module decode_mem_instr (
    input wire flash,
    input w32 instr,
    input w64 dest_phys,
    input Source src1,
    input Source src2,
    input w8 commit_id,
    output wire mem_en,
    output MemoryInstr mem_instr
);
    wire mem_en_ = ~((instr[31] ^ instr[30]) | instr[27] | instr[26]);
    wire filter = (instr[29] & instr[28]) ? 0 : ~flash;
    assign mem_en = mem_en_ & filter;

    assign mem_instr.commit_id = commit_id;
    assign mem_instr.ls = instr[28];
    assign mem_instr.pm = instr[24];
    assign mem_instr.addr = src2;
    assign mem_instr.offset = (mem_instr.ls) ? instr[15:8] : instr[23:16];
    always_comb begin
        if (mem_instr.ls) begin
            mem_instr.r.load.dest_logic = instr[23:16];
            mem_instr.r.load.dest_phys = dest_phys;
        end else begin
            mem_Instr.r.store = src1;
        end
    end
endmodule

module decode_uart_instr (
    input wire flash,
    input w32 instr,
    input w64 dest_phys,
    input Source src2,
    input w8 commit_id,
    output wire uart_en,
    output UartInstr uart_instr
);
    assign uart_en = (~((instr[31] ^ instr[30]) | instr[27] | ~instr[26])) ? ~flash : 0;

    assign uart_instr.commit_id = commit_id;
    assign uart_instr.sr = instr[31];
    always_comb begin
        if (uart_instr.sr) begin
            uart_instr.operand.send = src2;
        end else begin
            uart_instr.operand.recv.dest_logic = instr[23:16];
            uart_instr.operand.recv.dest_phys = dest_phys;
        end
    end
endmodule

module create_commit (
    input w32 instr,
    input w16 pc,
    output CommitEntry commit_entry
);
    assign commit_entry.kind = (instr[31] & ~instr[30]) | (instr[31] & instr[30] & instr[27]);
    assign commit_entry.notify_only = instr[31] & instr[30] & ~instr[29] & ~instr[27];
    always_comb begin
        if (commit_entry.kind) begin
            commit_entry.fin = 'd0;
            commit_entry.branch.miss = 'd0;
            commit_entry.branch.current_pc = pc;
        end else begin
            commit_entry.fin = instr[31] & instr[30] & ~instr[27];
            commit_entry.wb.dest_logic = (
                instr[31:30] == 'b00 && instr[27:26] == 'b11
            ) ? instr[7:0] : instr[23:16];
            commit_entry.wb.notify[0] = ~((instr[31] ^ instr[30]) | instr[27] | ~instr[26]);
            commit_entry.wb.notify[1] = instr[31] & instr[30] & ~instr[27] & ~instr[26];
        end
    end
endmodule


module InstructionDecode (
    input wire clock,
    input wire flash,
    // input wire stall,

    // input w32 instr,
    // input w16 pc,
    // input wire approx,
    Message.receiver if_result,

    // input CompleteInfo complete,
    // input CommitInfo commit,
    Message.receiver complete_info,
    Message.receiver commit_info,

    // IPushCommit.master push_commit,
    Message.sender commit_entry,
    input w8 commit_id,

    // output wire alu_en,
    // output AluInstr alu_instr,
    // output wire fpu_en,
    // output FpuInstr fpu_instr,
    // output wire bu_en,
    // output BranchInstr bu_instr,
    // output wire mem_en,
    // output MemoryInstr mem_instr,
    // output wire uart_en,
    // output UartInstr uart_instr
    Message.sender alu_instr,
    Message.sender fpu_instr,
    Message.sender branch_instr,
    Message.sender memory_instr,
    Message.sender uart_instr
);
    assign if_result.reject = (
        alu_instr.send_failed() | fpu_instr.send_failed() |
        branch_instr.send_failed() | memory_instr.send_failed() |
        uart_instr.send_failed() | commit_entry.send_failed()
    );

    // 命令からレジスタファイルに送るdest, srcを抽出
    w32 instr;
    assign instr = if_result.msg.instr;
    wire dest_en = if_result.en & instr[31] & ~if_result.reject;
    w8 dest_logic;
    assign dest_logic = (
        instr[31:30] == 'b00 && instr[27:26] == 'b11  // mov命令
    ) ? instr[7:0] : instr[23:16];
    w8 src1;
    assign src1 = instr[15:8];
    w8 src2;
    assign src2 = instr[7:0];

    // レジスタファイルの宣言
    Source read1, read2;
    w64 dest_phys;
    RegisterFile rf (
        .clock, .flash, .dest_en, .dest_logic, .src1, .src2,
        .complete_info, .commit_info, .read1, .read2, .dest_phys
    );

    // パイプライン分割
    r32 instr_ppl;
    r16 pc_ppl;
    reg approx_ppl;
    always_ff @(posedge clock) begin
        if (~if_result.reject) begin
            instr_ppl <= instr;
            pc_ppl <= if_result.msg.pc;
            approx_ppl <= if_result.msg.approx;
        end
    end

    // --- 1クロックの壁 ---

    Source processed1_orig, processed2_orig;
    process_read_data process_read_data (
        .instr(instr_ppl), .read1, .read2,
        .processed1(processed1_orig), .processed2(processed2_orig)
    );
    // リジェクト時の再送処理
    Source processed1_latch, processed2_latch;
    Source processed1, processed2;
    reg reject_1clock_behind;
    assign processed1 = (reject_1clock_behind) ? processed1_latch : processed1_orig;
    assign processed2 = (reject_1clock_behind) ? processed2_latch : processed2_orig;
    always_ff @(posedge clock) begin
        reject_1clock_behind <= if_result.reject;
        processed1_latch <= processed1;
        processed2_latch <= processed2;
    end


    // 各リザベーションステーションに向けてデータを詰める
    wire alu_en;
    decode_alu_instr decode_alu_instr (
        .flash, .instr(instr_ppl), .dest_phys, .commit_id,
        .src1(processed1), .src2(processed2), .alu_en, .alu_instr(alu_instr.msg)
    );
    assign alu_instr.en = alu_en & ~commit_entry.reject & if_result.en;

    wire fpu_en;
    decode_fpu_instr decode_fpu_instr (
        .flash, .instr(instr_ppl), .dest_phys, .commit_id,
        .src1(processed1), .src2(processed2), .fpu_en, .fpu_instr(fpu_instr.msg)
    );
    assign fpu_instr.en = fpu_en & ~commit_entry.reject & if_result.en;

    wire bu_en;
    decode_bu_instr decode_bu_instr (
        .flash, .instr(instr_ppl), .approx(approx_ppl), .pc(pc_ppl),
        .commit_id, .src1(processed1), .src2(processed2),
        .bu_en, .bu_instr
    );
    assign branch_instr.en = bu_en & ~commit_entry.reject & if_result.en;

    wire mem_en;
    decode_mem_instr decode_mem_instr (
        .flash, .instr(instr_ppl), .dest_phys, .commit_id,
        .src1(processed1), .src2(processed2), .mem_en, .mem_instr
    );
    assign memory_instr.en = mem_en & ~commit_entry.reject & if_result.en;

    wire uart_en;
    decode_uart_instr decode_uart_instr (
        .flash, .instr(instr_ppl), .dest_phys, .src2(processed2),
        .commit_id, .uart_en, .uart_instr(uart_instr.msg)
    );
    assign uart_instr.en = uart_en & ~commit_entry.reject & if_result.en;

    // コミットキューにデータを渡す
    assign commit_entry.en = if_result.en & ~flash;
    create_commit create_commit(
        .instr(instr_ppl), .pc(pc_ppl), .commit_entry(commit_entry.msg)
    );
endmodule
`include "../typedef.svh"
`include "bus.svh"

module AluRS #(
    N_LINE = 16
) (
    input wire clock,
    input wire flash,
    Message.receiver alu_instr,
    Message.receiver complete_info,
    Message.sender alu_result
);
    // Reservation Station
    AluInstr entry[N_LINE - 1:0];
    reg [N_LINE - 1:0] empty;

    // RSの空いているインデックスを探すのに用いる
    w8 empty_idx;
    wire full;
    PriorityEncoder #(N_LINE) (
        .b(empty), .lsb(empty_idx), .zero(full)
    );

    // RSのうち計算可能なエントリを探すのに用いる
    wire [N_LINE - 1:0] ready;
    w8 ready_idx;
    wire not_ready;
    for (genvar i = 0; i < N_LINE; i++) begin
        assign ready[i] = ~empty[i] & entry[i].src1.valid & entry[i].src2.valid;
    end
    PriorityEncoder #(N_LINE) (
        .b(ready), .lsb(ready_idx), .zero(not_ready)
    );

    always_ff @(posedge clock) begin
        if (flash) begin
            for (int i = 0; i < N_LINE; i++)
                empty[i] = 'd1;
        end else begin
            // completeをもとにソースレジスタ値を更新
            if (complete_info.en & ~complete_info.msg.kind) begin
                for (int i = 0; i < N_LINE; i++) begin
                    if (
                        ~entry[i].src1.valid &&
                        entry[i].src1.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src1.valid <= 'd1;
                        entry[i].src1.content.data <= complete_info.msg.content.wb.data;
                    end
                    
                    if (
                        ~entry[i].src2.valid &&
                        entry[i].src2.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src2.valid <= 'd1;
                        entry[i].src2.content.data <= complete_info.msg.content.wb.data;
                    end
                end
            end

            // エントリが計算されたら削除する
            if (~alu_result.reject & ~not_ready)
                empty[ready_idx] <= 'd1;
            
            // エントリの追加にかかる処理
            if (alu_instr.en & ~full) begin
                // フォールスルーはレジスタファイルの方で既に実施済み
                entry[empty_idx] <= alu_instr.msg;
                empty[empty_idx] <= 0;
            end
        end
    end

    // ALUを宣言
    ALU alu (.alu_instr(entry[ready_idx]), .result(alu_result.msg));
    assign alu_result.en = ~not_ready & ~flash;
    assign alu_instr.reject = full;
endmodule

module BuRS #(
    N_LINE = 16
) (
    input wire clock,
    input wire flash,
    Message.receiver branch_instr,
    Message.receiver complete_info,
    Message.sender bu_result
);
    // Reservation Station
    BranchInstr entry[N_LINE - 1:0];
    reg [N_LINE - 1:0] empty;

    // RSの空いているインデックスを探すのに用いる
    w8 empty_idx;
    wire full;
    PriorityEncoder #(N_LINE) (
        .b(empty), .lsb(empty_idx), .zero(full)
    );

    // RSのうち計算可能なエントリを探すのに用いる
    wire [N_LINE - 1:0] ready;
    w8 ready_idx;
    wire not_ready;
    for (genvar i = 0; i < N_LINE; i++) begin
        assign ready[i] = ~empty[i] & entry[i].src1.valid & entry[i].src2.valid;
    end
    PriorityEncoder #(N_LINE) (
        .b(ready), .lsb(ready_idx), .zero(not_ready)
    );

    always_ff @(posedge clock) begin
        if (flash) begin
            for (int i = 0; i < N_LINE; i++)
                empty[i] = 'd1;
        end else begin
            // completeをもとにソースレジスタ値を更新
            if (complete_info.en & ~complete_info.msg.kind) begin
                for (int i = 0; i < N_LINE; i++) begin
                    if (
                        ~entry[i].src1.valid &&
                        entry[i].src1.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src1.valid <= 'd1;
                        entry[i].src1.content.data <= complete_info.msg.content.wb.data;
                    end
                    
                    if (
                        ~entry[i].src2.valid &&
                        entry[i].src2.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src2.valid <= 'd1;
                        entry[i].src2.content.data <= complete_info.msg.content.wb.data;
                    end
                end
            end

            // エントリが計算されたら削除する
            if (~bu_result.reject & ~not_ready)
                empty[ready_idx] <= 'd1;
            
            // エントリの追加にかかる処理
            if (bu_instr.en & ~full) begin
                // フォールスルーはレジスタファイルの方で既に実施済み
                entry[empty_idx] <= bu_instr.msg;
                empty[empty_idx] <= 0;
            end
        end
    end

    // BUを宣言
    BranchUnit bu (.bu_instr(entry[ready_idx]), .result(bu_result.msg));
    assign bu_result.en = ~not_ready & ~flash;
    assign bu_instr.reject = full;
endmodule

module UartRS #(
    N_LINE = 16
) (
    input wire clock,
    input wire flash,
    Message.receiver uart_instr,
    Message.receiver complete_info,
    Message.receiver notify,
    Message.sender uart_result,
    ISendRequest.master io_send,
    IRecvRequest.master io_recv
);    
    // Reservation Station
    UartInstr entry[N_LINE - 1:0];
    w8 q_begin, q_end;
    UartInstr head;
    assign head = entry[q_begin];

    assign uart_instr.reject = ((q_end + 'd1) % N_LINE == q_begin) ? 'd1 : 'd0;

    always_ff @(posedge clock) begin
        if (flash) begin
            q_begin <= 0;
            q_end <= 0;
        end else begin
            // エントリの追加にかかる処理
            if (uart_instr.en & uart_instr.reject) begin
                entry[q_end] <= uart_instr.msg;
                q_end <= (q_end + 'd1) % N_LINE;
            end

            // completeをもとにソースレジスタ値を更新
            if (complete_info.en & ~complete_info.msg.kind) begin
                for (int i = 0; i < N_LINE; i++) begin
                    if (
                        entry[i].sr && ~entry[i].operand.send.valid &&
                        entry[i].operand.send.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].operand.send.valid <= 'd1;
                        entry[i].operand.send.content.data <= complete_info.msg.content.wb.data;
                    end
                end
            end

            // エントリの計算にかかる処理
            if (q_begin != q_end) begin
                if (head.sr) begin
                    if (notify.en && ~notify.reject) begin
                        io_send.send(head.operand.send.content.data);
                        q_begin <= (q_begin + 'd1) % N_LINE;
                    end
                end else begin
                    if (io_recv.en) begin
                        q_begin <= (q_begin + 'd1) % N_LINE;
                    end
                end
            end
        end
    end

    // 通知の制御
    always_comb begin
        io_recv.en = 0;
        notify.reject = 'd1;

        uart_result.en = 0;
        uart_result.msg.commit_id = head.commit_id;
        uart_result.msg.kind = 0;
        uart_result.msg.content.wb.dest_phys = head.operand.recv.dest_phys;
        uart_result.msg.content.wb.dest_logic = head.operand.recv.dest_logic;
        uart_result.msg.content.wb.data = io_recv.rd;

        if (q_begin != q_end) begin
            if (head.sr) begin
                notify.reject = io_send.busy | ~head.operand.send.valid;
            end else begin
                notify.reject = (io_recv.size == 0 || uart_result.reject) ? 'd1 : 'd0;
                io_recv.en = notify.en & ~notify.reject & ~flash;
                
                uart_result.en = io_recv.en;
            end
        end
    end
endmodule

module FpuRS #(
    N_LINE = 16
) (
    input wire clock,
    input wire flash,
    Message.receiver fpu_instr,
    Message.receiver complete_info,
    Message.sender fpu_result
);
    // Reservation Station
    FpuInstr entry[N_LINE - 1:0];
    reg [N_LINE - 1:0] empty;

    // RSの空いているインデックスを探すのに用いる
    w8 empty_idx;
    wire full;
    PriorityEncoder #(N_LINE) (
        .b(empty), .lsb(empty_idx), .zero(full)
    );

    // RSのうち計算可能なエントリを探すのに用いる
    wire [N_LINE - 1:0] ready;
    w8 ready_idx;
    wire not_ready;
    for (genvar i = 0; i < N_LINE; i++) begin
        assign ready[i] = ~empty[i] & entry[i].src1.valid & entry[i].src2.valid;
    end
    PriorityEncoder #(N_LINE) (
        .b(ready), .lsb(ready_idx), .zero(not_ready)
    );

    // FPUの宣言と入力の構成
    Message #(FpuInstr) to_fpu();
    CoreFpuInterconnect conn (
        .clock, .flash, .fpu_instr_orig(to_fpu.receiver), .fpu_result
    );
    assign to_fpu.en = ~not_ready & ~flash;
    assign to_fpu.msg = entry[ready_idx];

    always_ff @(posedge clock) begin
        if (flash) begin
            for (int i = 0; i < N_LINE; i++)
                empty[i] = 'd1;
        end else begin
            // completeをもとにソースレジスタ値を更新
            if (complete_info.en & ~complete_info.msg.kind) begin
                for (int i = 0; i < N_LINE; i++) begin
                    if (
                        ~entry[i].src1.valid &&
                        entry[i].src1.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src1.valid <= 'd1;
                        entry[i].src1.content.data <= complete_info.msg.content.wb.data;
                    end
                    
                    if (
                        ~entry[i].src2.valid &&
                        entry[i].src2.content.tag == complete_info.msg.content.wb.dest_phys
                    ) begin
                        entry[i].src2.valid <= 'd1;
                        entry[i].src2.content.data <= complete_info.msg.content.wb.data;
                    end
                end
            end

            // エントリの計算が開始されたら削除する
            if (~to_fpu.reject & ~not_ready)
                empty[ready_idx] <= 'd1;
            
            // エントリの追加にかかる処理
            if (fpu_instr.en & ~full) begin
                // フォールスルーはレジスタファイルの方で既に実施済み
                entry[empty_idx] <= fpu_instr.msg;
                empty[empty_idx] <= 0;
            end
        end
    end

    assign fpu_instr.reject = full;
endmodule

module MemRs #(
    N_LINE_S = 8,
    N_LINE_L = 8
) (
    input wire clock,
    input wire flash,
    ICache.master cache,
    Message.receiver mem_instr,
    Message.receiver complete_info,
    Message.receiver notify,
    Message.sender mem_result
);

endmodule
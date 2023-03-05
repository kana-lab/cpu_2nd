`include "../typedefs.svh"
`include "bus.svh"


module Core (
    input wire clock,
    input wire reset,

    IInstr.master instr_mem,
    ICache.master cache,
    ISendRequest.master io_send,
    IRecvRequest.master io_recv
);
    Message #(BranchResult) branch_result();  // 名前branch_infoの方がいいかも
    Message #(IFResult) if_result();
    Message #(Result) complete_info();
    Message #(CommitInfo) commit_info();
    Message #(CommitEntry) commit_entry();
    w8 commit_id;

    Message #(AluInstr) alu_instr();
    Message #(FpuInstr) fpu_instr();
    Message #(BranchInstr) branch_instr();
    Message #(MemoryInstr) memory_instr();
    Message #(UartInstr) uart_instr();

    Message notify[1:0]();

    Message #(Result) result_vec[4:0]();

    logic flash;
    assign flash = reset | (branch_result.en & branch_result.msg.miss);
    
    InstructionFetch instr_fetch (
        .clock, .reset,
        .instr_mem(instr_mem),
        .branch_result(branch_result.receiver),
        .if_result(if_result.sender)
    );

    InstructionDecode instr_decode (
        .clock, .flash,
        .if_result(if_result.receiver),
        .complete_info(complete_info.receiver),
        .commit_info(commit_info.receiver),
        .commit_entry(commit_entry.sender),
        .commit_id,
        
        .alu_instr(alu_instr.sender),
        .fpu_instr(fpu_instr.sender),
        .branch_instr(branch_instr.sender),
        .memory_instr(memory_instr.sender),
        .uart_instr(uart_instr.sender)
    );

    // 内部にTODOあり
    CommitQueue commit_q (
        .clock, .flash,
        .complete_info(complete_info.receiver),
        .commit_entry(commit_entry.receiver),
        .commit_info(commit_info.sender),
        .branch_result(branch_result.sender),
        .notify,
        .commit_id
    );

    ResultQueue #(.NUM_Q(5)) result_q (
        .clock, .flash,
        .r_vec(result_vec),
        .complete_info(complete_info.sender)
    );

    AluRS #(.N_LINE(8)) alu_rs (
        .clock, .flash,
        .alu_instr(alu_instr.receiver),
        .complete_info(complete_info.receiver),
        .alu_result(result_vec[0].sender)
    );

    BuRS #(.N_LINE(8)) bu_rs (
        .clock, .flash,
        .branch_instr(branch_instr.receiver),
        .complete_info(complete_info.receiver),
        .bu_result(result_vec[1].sender)
    );

    FpuRS #(.N_LINE(8)) fpu_rs (
        .clock, .flash,
        .fpu_instr(fpu_instr.receiver),
        .complete_info(complete_info.receiver),
        .fpu_result(result_vec[2].sender)
    );

    UartRS #(.N_LINE(8)) uart_rs (
        .clock, .flash,
        .uart_instr(uart_instr.receiver),
        .complete_info(complete_info.receiver),
        .notify(notify[0].receiver),
        .uart_result(result_vec[3].sender),
        .io_send, .io_recv
    );

    // 未実装
    MemRS #(.N_LINE(8)) mem_rs (
        .clock, .flash, .cache,
        .mem_instr(memory_instr.receiver),
        .complete_info(complete_info.receiver),
        .notify(notify[1].receiver),
        .mem_result(result_vec[4].sender)
    );
endmodule
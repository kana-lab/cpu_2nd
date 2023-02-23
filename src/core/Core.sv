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
    BranchResult branch_result;
    wire stall;

    // IF stage
    w32 instr;
    w32 pc;
    wire approx;
    InstructionFetch instr_fetch (
        .clock, .reset, .stall, .branch_result,
        .instr_mem, .instr_out(instr), .pc_out(pc), .approx_out(approx)
    );

    // IF stageで得た命令からレジスタファイルの入力を抽出する
    wire flash = branch_result.en & branch_result.miss;
    wire dest_en;
    w8 dest_logic;
    // w64 dest_phys;
    w8 src1;
    w8 src2;
    Extractor extractor (
        .clock, .flash, .stall, .instr,
        .dest_en, .dest_logic, .src1, .src2
    );

    // レジスタファイル
    Source read1, read2;
    w64 dest_phys;
    RegisterFile register_file (
        .clock, .flash, .dest_en, .dest_logic, .dest_phys, .src1, .src2,
        .complete(), .commit(), .read1, .read2, .dest_phys
    );

    // pipeline register
    r32 instr_pipeline1;
    r32 pc_pipeline1;
    reg approx_pipeline1;

    always_ff @(posedge clock) begin
        instr_pipeline1 <= instr;
        pc_pipeline1 <= pc;
        approx_pipeline1 <= approx;
    end

    // --- ここでパイプラインの分割 ---

    // TODO
endmodule
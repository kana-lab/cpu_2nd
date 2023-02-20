// module Core (
//     input wire clock,
//     input wire reset,

//     IInstr.master instr_mem,
//     ICache.master cache,
//     ISendRequest.master io_send,
//     IRecvRequest.master io_recv
// );
//     InstructionFetch instr_fetch (
//         .clock, .reset, .stall(), .branch_result(),
//         .instr_mem, .instr_out(), .pc_out(), .approx_out()
//     )
// endmodule
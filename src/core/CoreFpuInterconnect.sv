// module CoreFpuInterconnect (
//     input wire clock,
//     IFpu.slave request
// );
//     // stall中にval1, val2が保存されるようにする
//     reg [31:0] val1_saved;
//     reg [31:0] val2_saved;
//     always_ff @(posedge clock) begin
//         if (request.en) begin
//             val1_saved <= request.val1;
//             val2_saved <= request.val2;
//         end
//     end

//     wire valid, idle;
//     wire [31:0] x1 = (request.en) ? request.val1 : val1_saved;
//     wire [31:0] x2 = (request.en) ? request.val2 : val2_saved;
//     fpu fpu_i(
//         .clk(clock), .bram_clk(clock), .funct(request.funct), .x1, .x2,
//         .y(request.result), .en(request.en), .valid, .idle
//     );

//     assign request.stall = ~idle;
// endmodule

`include "../typedefs.svh"
`include "bus.svh"


module CoreFpuInterconnect (
    input wire clock,
    input wire flash,
    Message.receiver fpu_instr_orig,
    Message.sender fpu_result
);
    // 001: ready
    // 010: calculating
    // 100: waiting queue to be ready
    reg [2:0] state;

    // 入力をラッチし、FPUの計算中に入力が変化しないようにする
    wire en = fpu_instr_orig.en & ~fpu_instr_orig.reject;
    FpuInstr fpu_instr_saved, fpu_instr;
    always_ff @(posedge clock) begin
        if (en)
            fpu_instr_saved <= fpu_instr_orig.msg;
    end
    assign fpu_instr = (en) ? fpu_instr_orig.msg : fpu_instr_saved;

    // FPUの宣言と結果の構成
    wire idle;
    w32 y;
    fpu fpu_i (
        .clk(clock), .bram_clk(clock), .funct(fpu_instr.funct5),
        .x1(fpu_instr.src1.content.data), .x2(fpu_instr.src2.content.data),
        .y, .en, .valid(), .idle
    );
    Result r;
    assign r.commit_id = fpu_instr.commit_id;
    assign r.kind = 0;
    assign r.content.wb.dest_phys = fpu_instr.dest_phys;
    assign r.content.wb.dest_logic = fpu_instr.dest_logic;
    assign r.content.wb.data = y;

    // FPUの計算終了を判定
    wire stall = ~idle;
    reg stall_1clock_behind;
    always_ff @(posedge clock)
        stall_1clock_behind <= (flash) ? 0 : stall;
    wire exec_finished = ~stall & stall_1clock_behind;
    
    // ステートマシンの構成
    Result r_saved;
    always_ff @(posedge clock) begin
        if (flash) begin
            state <= 'b001;
        end else begin
            if (state[0]) begin
                if (fpu_instr_orig.en)
                    state <= 'b010;
            end

            if (state[1]) begin
                if (exec_finished) begin
                    r_saved <= r;

                    if (~fpu_result.reject) begin
                        if (~fpu_instr_orig.en)
                            state <= 'b001;
                    end else begin
                        state <= 'b100;
                    end
                end
            end

            if (state[2]) begin
                if (~fpu_result.reject) begin
                    state <= (fpu_instr_orig.en) ? 'b010 : 'b001;
                end
            end
        end
    end

    // 結果の送信
    assign fpu_result.en = exec_finished | state[2];
    assign fpu_result.msg = (exec_finished) ? r : r_saved;

    assign fpu_instr_orig.reject = ~(state[0] | ((exec_finished | state[2]) & ~fpu_result.reject));
endmodule
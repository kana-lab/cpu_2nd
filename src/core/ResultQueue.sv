`include "../typedefs.svh"
`include "bus.svh"


// リザベーションステーション毎に用意されるキューを表すモジュール
// 分散RAMで試したところ莫大なLUTを消費してしまったため、BRAM上に確保する事にした
// 読み出しと書き込みを同時に行うためにdual port BRAMが必要だが、これをinferさせるには
// 以下のように二つのモジュールを用意する必要がある
//     参考: https://support.xilinx.com/s/article/56457?language=en_US
module PartialResultQueueInst #(
    Q_SIZE = 32
) (
    input wire clock,
    input w8 w_addr,
    input wire [48:0] w_data,
    input w8 r_addr,
    output wire [48:0] r_data
);
    (* ram_style = "block" *)reg [48:0] bram[Q_SIZE - 1:0];

    always_ff @(posedge clock) begin
        bram[w_addr] <= w_data;
    end

    assign r_data = bram[r_addr];
endmodule

module PartialResultQueue #(
    Q_SIZE = 32
) (
    input wire clock,
    input w8 w_addr,
    input wire [48:0] w_data,
    input w8 r_addr,
    output reg [48:0] r_data
);
    wire [48:0] read_tmp;
    PartialResultQueueInst #(.Q_SIZE(Q_SIZE)) inst (
        .clock, .w_addr, .w_data, .r_data(read_tmp)
    );

    always_ff @(posedge clock) begin
        r_data <= read_tmp;
    end
endmodule

module ResultQueue #(
    NUM_Q = 7
) (
    input wire clock,
    input wire flash,
    // input wire stall,

    // input Result r_vec[NUM_Q - 1:0],
    // output wire q_full[NUM_Q - 1:0],
    Message.receive r_vec[NUM_Q - 1:0],

    Message.sender complete_info
);
    localparam N = NUM_Q;

    // リザベーションステーション毎にキューを用意
    w8 pq_w_addr[N - 1:0];
    wire [48:0] pq_w_data[N - 1:0];
    w8 pq_r_addr[N - 1:0];
    wire [48:0] pq_r_data[N - 1:0];
    for(genvar i = 0; i < N; i++) begin
        PartialResultQueue q (
            .clock, .w_addr(pq_w_addr[i]),
            .w_data(pq_w_data[i]), .r_addr(pq_r_addr[i]),
            .r_data(pq_r_data[i])
        );
    end
    r8 q_begin[N - 1:0];
    r8 q_end[N - 1:0];

    // どのキューからpopするかを決定するpriority encoderの宣言
    wire [N - 1:0] ready_q;
    wire [N - 1:0] ready_input;
    w8 offset_q, offset_input;
    wire empty_q, empry_input;
    for (genvar i = 0; i < N; i++) begin
        assign ready_q[i] = (q_end[i] != q_begin[i]) ? 'd1 : 'd0;
        // todo: fullであってもそのクロックでpopされる場合はOK
        assign r_vec[i].reject = ((q_end[i] + 'd1) % 'd32) == q_begin[i] ? 'd1 : 'd0;
        assign ready_input[i] = r_vec[i].en;
    end
    PriorityEncoder #(N) q_priority (
        .b(ready_q), .lsb(offset_q), .zero(empty_q)
    );
    PriorityEncoder #(N) input_priority (
        .b(ready_input), .lsb(offset_input), .zero(empty_input)
    );

    // キューのインデックス管理
    Result fall_through;
    reg fall_through_exist;
    reg empty_q_ppl;
    r8 offset_q_ppl;
    always_ff @(posedge clock) begin
        offset_q_ppl <= offset_q;

        if (flash) begin
            for (int i = 0; i < N; i++) begin
                q_begin[i] <= 0;
                q_end[i] <= 0;
            end

            fall_through_exist <= 0;
            empty_q_ppl <= 'd1;
        end else begin
            empty_q_ppl <= empty_q;

            if (~complete_info.reject) begin
                if (empty_q) begin
                    for (int i = 0; i < N; i++) begin
                        if (r_vec[i].en && i != offset_input)
                            q_end[i] <= (q_end[i] + 'd1) % 'd32;
                    end

                    fall_through_exist <= ~empty_input;
                    fall_through <= r_vec[offset_input].msg;
                end else begin
                    for (int i = 0; i < N; i++) begin
                        if (r_vec[i].en & ~r_vec[i].reject)
                            q_end[i] <= (q_end[i] + 'd1) % 'd32;
                    end

                    fall_through_exist <= 0;
                end

                if (~empty_q_ppl) begin
                    if (~fall_through_exist)
                        q_begin[offset_q_ppl] <= q_begin[offset_q_ppl] + 'd1;
                end
            end else begin
                for (int i = 0; i < N; i++) begin
                    if (r_vec[i].en & ~r_vec[i].reject)
                        q_end[i] <= (q_end[i] + 'd1) % 'd32;
                end
            end
        end
    end

    // キューの操作に必要なデータを送信
    for (genvar i = 0; i < N; i++) begin
        assign pq_w_addr[i] = q_end[i];
        assign pq_w_data[i] = r_vec[i].msg;
        assign pq_r_addr[i] = q_begin[offset_q];
    end

    // キューから読みだしたデータをcompleteに格納
    assign complete_info.msg = (fall_through_exist) ? fall_through : Result'(pq_r_data[offset_q_ppl]);
    assign complete_info.en = ~flash & ~complete_info.reject & (fall_through_exist | ~empty_q_ppl);
endmodule
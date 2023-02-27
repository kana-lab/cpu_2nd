`include "../typedefs.svh"
`include "bus.svh"

// 複数のキューからpop可能なものを一つ選択するのに使用する
// BIT_WIDTH must be >= 1
module PriorityEncoder #(
    BIT_WIDTH
) (
    input wire [BIT_WIDTH - 1:0] b,
    output w8 lsb,
    output wire zero
);
    localparam M = BIT_WIDTH / 2;
    generate
        if (BIT_WIDTH == 1) begin
            assign lsb = 0;
            assign zero = ~b[0];
        end else begin
            w8 lower_lsb;
            wire lower_zero;
            PriorityEncoder #(M) p_l (
                .b(b[M - 1:0]), .lsb(lower_lsb), .zero(lower_zero)
            );
            w8 higher_lsb;
            wire higher_zero;
            PriorityEncoder #(BIT_WIDTH - M) p_h (
                .b(b[BIT_WIDTH - 1:M]), .lsb(higher_lsb), .zero(higher_zero)
            );

            assign lsb = (lower_zero) ? higher_lsb + M : lower_lsb;
            assign zero = lower_zero & higher_zero;
        end
    endgenerate
endmodule

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
    input wire [49:0] w_data,
    input w8 r_addr,
    output wire [49:0] r_data
);
    (* ram_style = "block" *)reg [49:0] bram[Q_SIZE - 1:0];

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
    input wire [49:0] w_data,
    input w8 r_addr,
    output reg [49:0] r_data
);
    wire [49:0] read_tmp;
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
    input wire stall,

    input Result r_vec[NUM_Q - 1:0],
    output wire q_full[NUM_Q - 1:0],

    output Result complete
);
    localparam N = NUM_Q;

    // リザベーションステーション毎にキューを用意
    w8 pq_w_addr[N - 1:0];
    wire [49:0] pq_w_data[N - 1:0];
    w8 pq_r_addr[N - 1:0];
    wire [49:0] pq_r_data[N - 1:0];
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
    wire [N - 1:0] ready;
    for (genvar i = 0; i < N; i++) begin
        assign ready[i] = (q_end[i] != q_begin[i]) ? 'd1 : 'd0;
        assign q_full[i] = ((q_end[i] + 'd1) % 'd32) == q_begin[i] ? 'd1 : 'd0;
    end
    w8 offset;
    wire empty;
    PriorityEncoder #(N) priority_encoder (
        .b(ready), .lsb(offset), .zero(empty)
    );

    // キューのインデックス管理
    reg empty_ppl;
    always_ff @(posedge clock) begin
        if (flash) begin
            for (int i = 0; i < N; i++) begin
                q_begin[i] <= 0;
                q_end[i] <= 0;
                empty_ppl <= 0;
            end
        end else begin
            for (int i = 0; i < N; i++) begin
                if (r_vec[i].en)
                    q_end[i] <= (q_end[i] + 'd1) % 'd32;
            end

            empty_ppl <= empty;
            if (~empty)
                q_begin[offset] <= (q_begin[offset] + 'd1) % 'd32;
        end
    end

    // キューの操作に必要なデータを送信
    for (genvar i = 0; i < N; i++) begin
        assign pq_w_addr[i] = q_end[i];
        assign pq_w_data[i] = r_vec[i];
        assign pq_r_addr[i] = q_begin[offset];
    end

    // キューから読みだしたデータをcompleteに格納
    Result read;
    assign read = Result'(pq_r_data[offset]);
    assign complete.commit_id = read.commit_id;
    assign complete.kind = read.kind;
    assign complete.content = read.content;
    assign complete.en = ~(empty_ppl | stall | flash);
endmodule
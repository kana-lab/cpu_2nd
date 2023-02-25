`include "../typedefs.svh"
`include "bus.svh"

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

// ResultQueueはストールを発生させない保証あり
// - リザベーションステーションへpushされた命令の結果が偏ってResultQueueへpushされる
// - RS全体で、1clockにつき1命令がpushされる
// 以上よりResultQueueのサイズがRS全体のキャパシティを上回ればストールを発生させない
module ResultQueue #(
    NUM_FPU = 3,
    Q_SIZE = 256
) (
    input wire clock,
    input wire flash,
    input wire stall,

    input Result r_alu,
    input Result r_bu,
    input Result r_mem,
    input Result r_uart,
    input Result r_fpu[NUM_FPU - 1:0],

    output Result complete
);
    Result r_vec[NUM_FPU + 4 - 1:0];
    assign r_vec[0] = r_alu;
    assign r_vec[1] = r_bu;
    assign r_vec[2] = r_mem;
    assign r_vec[3] = r_uart;
    for (genvar i = 0; i < NUM_FPU; i++) begin
        assign r_vec[i + 4] = r_fpu[i];
    end

    w8 en_vec[NUM_FPU + 4 - 1:0];
    for (genvar i = 0; i < NUM_FPU + 4; i++) begin
        assign en_vec[i] = {7'd0, r_vec[i].en};
    end
    
    w8 offset[NUM_FPU + 4 - 1:0];
    assign offset[0] = 0;
    for (genvar i = 1; i < NUM_FPU + 4; i++) begin
        assign offset[i] = offset[i - 1] + en_vec[i - 1];
    end
    w8 num_pushed;
    assign num_pushed = offset[NUM_FPU + 4 - 1] + en_vec[NUM_FPU + 4 - 1];

    r8 q_begin, q_end;
    (* ram_style = "block" *)Result q[Q_SIZE - 1:0];

    always_ff @(posedge clock) begin
        if (flash) begin
            q_begin <= 0;
            q_end <= 0;
        end else if (~stall) begin
            // for (int i = 0; i < NUM_FPU + 4; i++) begin
            //     if (r_vec[i].en)
            //         q[q_end + offset[i]] <= r_vec[i];
            // end
            q[q_end] <= r_vec[0];
            // q_end <= (q_end + (en_vec.sum() with (8'(item)))) % Q_SIZE;
            q_end <= (q_end + num_pushed) % Q_SIZE;

            if (q_begin != q_end) begin
                q_begin <= (q_begin + 'd1) % Q_SIZE;
            end
        end
    end

    Result filtered;
    assign filtered.commit_id = q[q_begin].commit_id;
    assign filtered.kind = q[q_begin].kind;
    assign filtered.content = q[q_begin].content;
    assign filtered.en = q[q_begin].en & ~(stall | flash);
    assign complete = filtered;
endmodule

// interface IPartialResultQueue;
//     w8 w_addr;
//     Result w_data;
//     w8 r_addr;
//     Result r_data;

//     modport master (
//         input r_data,
//         output w_addr, w_data, r_addr
//     );

//     modport slave (
//         input w_addr, w_data, r_addr,
//         output r_data
//     );
// endinterface

typedef struct packed {
    w8 w_addr;
    Result w_data;
    w8 r_addr;
} IPartialResultQueueIn;

module PartialResultQueueInst #(
    Q_SIZE = 32
) (
    input wire clock,
    // IPartialResultQueue.slave instr
    // input IPartialResultQueueIn instr,
    input w8 w_addr,
    input wire [49:0] w_data,
    input w8 r_addr,
    output wire [49:0] r_data
    // output Result read
);
    (* ram_style = "block" *)reg [49:0] bram[Q_SIZE - 1:0];

    always_ff @(posedge clock) begin
        // bram[instr.w_addr] <= instr.w_data;
        bram[w_addr] <= w_data;
        // instr.r_data <= bram[instr.r_addr];
        // read <= bram[instr.r_addr];
    end

    // assign read = bram[instr.r_addr];
    assign r_data = bram[r_addr];
endmodule

module PartialResultQueue #(
    Q_SIZE = 32
) (
    input wire clock,
    // input IPartialResultQueueIn instr,
    input w8 w_addr,
    input wire [49:0] w_data,
    input w8 r_addr,
    output reg [49:0] r_data
    // output Result read
);
    wire [49:0] read_tmp;
    PartialResultQueueInst #(.Q_SIZE(Q_SIZE)) inst (
        // .clock, .instr, .read(read_tmp)
        .clock, .w_addr, .w_data, .r_data(read_tmp)
    );

    always_ff @(posedge clock) begin
        // read <= read_tmp;
        r_data <= read_tmp;
    end
endmodule

module ResultQueueBram #(
    NUM_FPU = 3,
    Q_SIZE = 256
) (
    input wire clock,
    input wire flash,
    input wire stall,

    input Result r_alu,
    input Result r_bu,
    input Result r_mem,
    input Result r_uart,
    input Result r_fpu[NUM_FPU - 1:0],

    output Result complete
);
    localparam N = NUM_FPU + 4;
    Result r_vec[N - 1:0];
    assign r_vec[0] = r_alu;
    assign r_vec[1] = r_bu;
    assign r_vec[2] = r_mem;
    assign r_vec[3] = r_uart;
    for (genvar i = 0; i < NUM_FPU; i++) begin
        assign r_vec[i + 4] = r_fpu[i];
    end

    // (* ram_style = "block" *)Result q[N - 1:0][31:0];
    // IPartialResultQueue iprq[N - 1:0]();
    // IPartialResultQueueIn [N - 1:0] iprq;
    w8 pq_w_addr[N - 1:0];
    wire [49:0] pq_w_data[N - 1:0];
    w8 pq_r_addr[N - 1:0];
    wire [49:0] pq_r_data[N - 1:0];
    // Result [N - 1:0] read;
    for(genvar i = 0; i < N; i++) begin
        PartialResultQueue q (
            // .clock(CLK100MHZ), .instr(iprq[i]), .read(read[i])
            .clock, .w_addr(pq_w_addr[i]),
            .w_data(pq_w_data[i]), .r_addr(pq_r_addr[i]),
            .r_data(pq_r_data[i])
        );
    end
    r8 q_begin[N - 1:0];
    r8 q_end[N - 1:0];

    wire [N - 1:0] ready;
    for (genvar i = 0; i < N; i++)
        assign ready[i] = (q_end[i] != q_begin[i]) ? 'd1 : 'd0;
    w8 offset;
    wire empty;
    PriorityEncoder #(N) priority_encoder (
        .b(ready), .lsb(offset), .zero(empty)
    );

    // Result fetched;
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
                // q[i][q_end[i]] <= r_vec[i];
                if (r_vec[i].en)
                    q_end[i] <= (q_end[i] + 'd1) % 'd32;
            end

            // fetched <= q[offset][q_begin[offset]];
            empty_ppl <= empty;
            if (~empty)
                q_begin[offset] <= (q_begin[offset] + 'd1) % 'd32;
        end
    end

    for (genvar i = 0; i < N; i++) begin
        // assign iprq[i].w_addr = q_end[i];
        // assign iprq[i].w_data = r_vec[i];
        // assign iprq[i].r_addr = q_begin[offset];
        assign pq_w_addr[i] = q_end[i];
        assign pq_w_data[i] = r_vec[i];
        assign pq_r_addr[i] = q_begin[offset];
    end

    Result read;
    assign read = Result'(pq_r_data[offset]);
    assign complete.commit_id = read.commit_id;
    assign complete.kind = read.kind;
    assign complete.content = read.content;
    assign complete.en = ~(empty_ppl | stall | flash);
endmodule
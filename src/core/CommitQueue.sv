`include "../typedefs.svh"
`include "bus.svh"


// module PartialCommitQueueInst #(
//     Q_SIZE = 256
// ) (
//     input wire clock,
//     input w8 w_addr,
//     input wire [43:0] w_data,
//     input w8 r_addr,
//     output wire [43:0] r_data
// );
//     (* ram_style = "block" *)reg [43:0] bram[Q_SIZE - 1:0];

//     always_ff @(posedge clock) begin
//         bram[w_addr] <= w_data;
//     end

//     assign r_data = bram[r_addr];
// endmodule

// module PartialCommitQueue #(
//     Q_SIZE = 256
// ) (
//     input wire clock,
//     input w8 w_addr,
//     input wire [43:0] w_data,
//     input w8 r_addr,
//     output reg [43:0] r_data
// );
//     wire [43:0] read_tmp;
//     PartialResultQueueInst #(.Q_SIZE(Q_SIZE)) inst (
//         .clock, .w_addr, .w_data, .r_data(read_tmp)
//     );

//     always_ff @(posedge clock) begin
//         r_data <= read_tmp;
//     end
// endmodule

// LUTが溢れないかが心配すぎる。。。
module CommitQueue #(
    Q_SIZE = 256
) (
    input wire clock,
    input wire reset,

    Message.receiver complete_info,
    Message.receiver commit_entry,
    Message.sender commit_info,
    Message.sender branch_result,
    Message.sender notify[1:0],
    output w8 commit_id
);
    // // true dual-port RAMを宣言
    // w8 w_addr;
    // wire [43:0] w_data;
    // w8 r_addr;
    // wire [43:0] r_data;
    // PartialCommitQueue #(Q_SIZE) (
    //     .clock, .w_addr, .w_data, .r_addr, .r_data
    // );

    // queueのindexを宣言
    r8 q_begin, q_end;
    CommitEntry entry[Q_SIZE - 1:0];

    CommitEntry head;
    assign head = entry[q_begin];

    always_ff @(posedge clock) begin
        if (reset) begin
            q_begin <= 0;
            q_end <= 0;
        end else begin
            if (commit_entry.en) begin
                entry[q_end] <= commit_entry.msg;
                q_end <= (q_end + 'd1) % Q_SIZE;
            end

            if (complete_info.en) begin
                entry[complete_info.msg.commit_id].fin <= 'd1;

                if (complete_info.msg.kind) begin
                    entry[complete_info.msg.commit_id].content.branch.miss <= complete_info.msg.content.branch.miss;
                    entry[complete_info.msg.commit_id].content.branch.taken <= complete_info.msg.content.branch.taken;
                    entry[complete_info.msg.commit_id].content.branch.new_pc <= complete_info.msg.content.branch.new_pc;
                end else begin
                    entry[complete_info.msg.commit_id].content.wb.data <= complete_info.msg.content.wb.data;
                end
            end

            if (head.kind) begin
                if (head.fin)
                    q_begin <= (q_begin + 'd1) % Q_SIZE;
            end else begin
                if (head.content.wb.notify == 'b00) begin
                    if (head.fin)
                        q_begin <= (q_begin + 'd1) % Q_SIZE;
                end else begin
                    if (notify[0].en)
                        entry[q_begin].content.wb.notify[0] <= 0;
                    if (notify[1].en)
                        entry[q_begin].content.wb.notify[1] <= 0;
                end
            end
        end
    end

    always_comb begin
        commit_entry.reject = ((q_end + 'd1) % Q_SIZE == q_begin) ? 'd1 : 'd0;
        complete_info.reject = 0;

        commid_id = q_end;

        branch_result.en = head.fin & head.kind;
        branch_result.msg = head.content.branch;
        commit_info.en = (head.fin && ~head.kind && ~head.notify_only && head.content.wb.notify == 'b00) ? 'd1 : 'd0;
        commit_info.msg.dest_logic = head.content.wb.dest_logic;
        commit_info.msg.data = head.content.wb.data;

        notify[0].en = ~head.kind & head.content.wb.notify[0] & notify[0].reject;
        notify[1].en = ~head.kind & head.content.wb.notify[1] & notify[1].reject;
    end
endmodule
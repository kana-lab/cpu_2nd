`include "../typedefs.svh"
`include "bus.svh"

typedef struct {
    reg place;  // 0: architecture, 1: physical
    r32 arch_data;
    reg phys_valid;
    union {
        w32 data;
        w64 tag;
    } phys;
} Register;

// flash中は他の入力は無視する仕様とする
// 必要があればまた書き換えること
module RegisterFile (
    input wire clock,
    input wire flash,

    input wire dest_en,
    input w8 dest_logic,
    input w8 src1,
    input w8 src2,

    Message.receiver complete_info,
    Message.receiver commit_info,

    output Source read1,
    output Source read2,
    output r64 dest_phys
);
    assign complete_info.reject = 'd0;
    assign commit_info.reject = 'd0;
    
    Register register[255:0];
    r64 tag_generator;

    wire complete_established = (
        complete_info.en &&
        ~register[complete_info.msg.dest_logic].phys_valid &&
        register[complete_info.msg.dest_logic].phys.tag == complete_info.msg.dest_phys
    ) ? 'd1 : 'd0;

    always_ff @(posedge clock) begin
        if (flash) begin
            tag_generator <= 0;
            for (int i = 0; i < 256; i++)
                register[i].place <= 0;
        end else begin
            if (dest_en) begin
                tag_generator <= tag_generator + 'd1;
                register[dest_logic].place <= 'd1;
                register[dest_logic].phys_valid <= 0;
                register[dest_logic].phys.tag <= dest_phys;
            end

            if (commit_info.en)
                register[commit_info.msg.dest_logic].arch_data <= commit_info.msg.data;

            if (
                complete_established &&
                // 入力とcomleteが被った場合入力優先
                ~(dest_en && dest_logic == complete_info.msg.dest_logic)
            ) begin
                register[complete_info.msg.dest_logic].phys_valid <= 'd1;
                register[complete_info.msg.dest_logic].phys.data <= complete_info.msg.data;
            end

            // src1の読み出し
            if (complete_established && src1 == complete_info.msg.dest_logic) begin
                read1.valid <= 'd1;
                read1.content.data <= complete_info.msg.data;
            end else begin
                if (register[src1].place) begin
                    read1.valid <= register[src1].phys_valid;
                    if (register[src1].phys_valid) begin
                        read1.content.data <= register[src1].phys.data;
                    end else begin
                        read1.content.tag <= register[src1].phys.tag;
                    end
                end else begin
                    read1.valid <= 'd1;
                    read1.content.data <= register[src1].arch_data;
                end
            end
            
            // src2の読み出し
            if (complete_established && src2 == complete_info.msg.dest_logic) begin
                read2.valid <= 'd1;
                read2.content.data <= complete_info.msg.data;
            end else begin
                if (register[src2].place) begin
                    read2.valid <= register[src2].phys_valid;
                    if (register[src2].phys_valid) begin
                        read2.content.data <= register[src2].phys.data;
                    end else begin
                        read2.content.tag <= register[src2].phys.tag;
                    end
                end else begin
                    read2.valid <= 'd1;
                    read2.content.data <= register[src2].arch_data;
                end
            end
        end
    end
endmodule

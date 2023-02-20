`include "typedefs.svh"

// このモジュールは要テスト
module RingBuf #(
    BUF_SIZE = 32'd512
) (
    input wire clock,
    input wire reset,

    input wire we,
    input w32 wd,
    input wire re,
    output r32 rd,
    output w32 size,
    output reg overflow
);
    r32 m[BUF_SIZE - 1:0];

    r32 m_start;
    r32 m_end;
    assign size = (BUF_SIZE + m_end - m_start) % BUF_SIZE;
    // assign rd = m[m_start];

    always_ff @(posedge clock) begin
        if (reset) begin
            m_start <= 0;
            m_end <= 0;
            overflow <= 0;
        end else begin
            if (we) begin
                m_end <= (m_end + 'd1) % BUF_SIZE;
                m[m_end] <= wd;

                if (size == BUF_SIZE - 1 && ~re) begin
                    overflow <= 'd1;
                    m_start <= (m_start + 'd1) % BUF_SIZE;
                end
            end

            if (re) begin
                overflow <= 0;
                m_start <= (m_start + 'd1) % BUF_SIZE;
                rd <= m[m_start];
            end
        end
    end
endmodule
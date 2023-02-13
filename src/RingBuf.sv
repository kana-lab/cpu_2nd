// このモジュールは要テスト
module RingBuf #(
    BUF_SIZE = 32'd512
) (
    input wire clock,
    input wire reset,

    input wire we,
    input wire [31:0] wd,
    input wire re,
    output wire [31:0] rd,
    output wire [31:0] size,
    output reg overflow
);
    reg [31:0] m[BUF_SIZE - 1:0];

    reg [31:0] m_start;
    reg [31:0] m_end;
    assign size = (BUF_SIZE + m_end - m_start) % BUF_SIZE;
    assign rd = m[m_start];

    always_ff @(posedge clock) begin
        if (reset) begin
            m_start <= 0;
            m_end <= 0;
            overflow <= 0;
        end else begin
            if (we) begin
                m_end <= (m_end + 32'd1) % BUF_SIZE;
                m[m_end] <= wd;

                if (size == BUF_SIZE - 1 && ~re) begin
                    overflow <= 1'b1;
                    m_start <= (m_start + 32'd1) % BUF_SIZE;
                end
            end

            if (re) begin
                overflow <= 0;
                m_start <= (m_start + 32'd1) % BUF_SIZE;
            end
        end
    end
endmodule
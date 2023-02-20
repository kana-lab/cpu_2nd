`include "typedefs.svh"

module UartRx #(
    CLK_PER_HALF_BIT = 30
) (
    input wire clock,
    input wire reset,
    input wire rxd_orig,

    output reg rx_ready,
    output r8 rdata,
    output reg ferr
);
    // チャタリング等の回避のためにバッファリングする
    (* ASYNC_REG = "true" *) reg [2:0] sync_reg;
    wire rxd = sync_reg[0];
    wire [2:0] next_sync_reg = {rxd_orig, sync_reg[2:1]};
    wire is_stable = (sync_reg == 'b111 || sync_reg == 'b0) ? 'b1 : 'b0;

    always_ff @(posedge clock) begin
        if (reset) begin
            sync_reg <= 'b111;
        end else begin
            sync_reg <= next_sync_reg;
        end
    end
    // wire rxd = rxd_orig;
    // wire is_stable = 1'b1;

    // 以下UART本体の実装

    localparam CLK_PER_ONE_BIT = CLK_PER_HALF_BIT * 2;
    localparam CLK_TILL_STOP_BIT = CLK_PER_ONE_BIT * 6 / 10;

    // 受信状態を表すシフトレジスタ
    // 0001: idle状態
    // 0010: start bitの立ち下がりを検出した状態
    // 0100: start bitがLowである事を検証し終えて、これからデータの受信を開始し始める状態
    // 1000: データを受信し終えて、これからstop bitを検出しようとする状態
    reg [3:0] state;
    wire [3:0] next_state = {state[2:0], state[3]};

    // データを何bit受信したかを表すシフトレジスタ
    reg [8:0] n_recv;
    wire [8:0] next_n_recv = {n_recv[7:0], n_recv[8]};

    // 適切なタイミングでデータを取り込むためのclockのカウンタ
    r32 counter;

    // rdataにrxdをプッシュしておく
    w8 rdata_pushed = {rxd, rdata[7:1]};

    always_ff @(posedge clock) begin
        if (reset) begin
            rx_ready <= 0;
            ferr <= 0;

            state <= 'd1;
            n_recv <= 'd1;
            counter <= 0;
        end else if (~ferr) begin
            if (rx_ready) rx_ready <= 0;

            if (state[0] & is_stable & ~rxd) begin
                counter <= 0;
                state <= next_state;
            end

            if (state[1]) begin
                if (counter > CLK_PER_HALF_BIT - 1 && is_stable) begin
                    counter <= 0;
                    ferr <= rxd;
                    state <= next_state;
                end else begin
                    counter <= counter + 'd1;
                end
            end

            if (state[2]) begin
                if (counter > CLK_PER_ONE_BIT - 1 && is_stable) begin
                    counter <= 0;
                    n_recv <= next_n_recv;
                    rdata <= rdata_pushed;
                end else begin
                    counter <= counter + 'd1;
                end

                // 厳密なことを言うとここでワンクロック遅れるのでcounterは1になる
                // ifのネストを深くしないための配慮
                if (n_recv[8]) begin
                    state <= next_state;
                    n_recv <= next_n_recv;
                end
            end

            if (state[3]) begin
                if (counter > CLK_TILL_STOP_BIT - 1 && is_stable) begin
                    rx_ready <= rxd;
                    ferr <= ~rxd;
                    state <= next_state;
                end else begin
                    counter <= counter + 'd1;
                end
            end
        end
    end
endmodule

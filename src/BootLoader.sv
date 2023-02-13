module BootLoader #(
    INTERVAL_0x99 = 100
) (
    input wire clock,
    input wire reset,

    // UARTのレシーバからの信号
    input wire rx_ready,
    input wire [7:0] rdata,

    // UARTのセンダーからの/への信号
    input wire tx_busy,
    output reg tx_start,
    output reg [7:0] sdata,

    // 受け取ったデータ
    output reg instr_ready,
    output reg data_ready,
    output reg [31:0] content,

    // ブート終了を表す信号
    output wire program_loaded
);
    // server/readme.pdfの仕様に従って実装する

    // 0001: 初期状態
    // 0010: 0x99を送った後、プログラムサイズを取得しようとしている状態
    // 0100: プログラムを取得しようとしている状態
    // 1000: プログラムを取得して0xaaを送った後、データを取得している状態
    reg [3:0] state;
    wire [3:0] next_state = {state[2:0], 1'b0};
    assign program_loaded = state[3];

    // 0001: int型の値の1byte目を取得しようとしている状態
    // ...
    // 1000: int型の値の4byte目を取得しようとしている状態
    reg [3:0] n_byte;
    wire [3:0] next_n_byte = {n_byte[2:0], n_byte[3]};

    wire [31:0] next_content = {rdata, content[31:8]};

    // プログラムサイズ(little endian)
    reg [31:0] program_size;
    reg [31:0] program_received;

    // 0x99を送り続ける間隔
    reg [7:0] counter;

    always_ff @(posedge clock) begin
        if (reset) begin
            state <= 4'b1;
            n_byte <= 4'b1;
            program_size <= 0;
            program_received <= 0;
            counter <= 0;

            tx_start <= 0;
            instr_ready <= 0;
            data_ready <= 0;
        end else begin
            if (tx_start) tx_start <= 0;
            if (instr_ready) instr_ready <= 0;
            if (data_ready) data_ready <= 0;

            // 最初に0x99を繰り返し送り、PC側が反応を示すのを待つ
            if (state[0]) begin
                if (counter >= INTERVAL_0x99 && ~tx_busy) begin
                    tx_start <= 1'b1;
                    sdata <= 8'h99;
                    counter <= 0;
                end else begin
                    counter <= counter + 8'd1;
                end

                if (rx_ready)
                    state <= next_state;
            end

            if (state[2] == 1'b1 && program_size == program_received) begin
                if (~tx_busy) begin
                    tx_start <= 1'b1;
                    sdata <= 8'haa;
                    state <= next_state;
                end
            end
            
            // 仕様を満たさない余分な受信データがあった場合正常に動作しない
            // また、プログラムおよびデータは4の倍数byteでないと正確に受信されない
            if (rx_ready) begin
                content <= next_content;
                n_byte <= next_n_byte;

                if (state[1] & n_byte[3]) begin
                    program_size <= next_content;
                    state <= next_state;
                end

                if (state[2]) begin
                    program_received <= program_received + 32'd1;
                    if (n_byte[3]) instr_ready <= 1'b1;
                end

                if (state[3] & n_byte[3]) begin
                    data_ready <= 1'b1;
                end
            end
        end
    end
endmodule
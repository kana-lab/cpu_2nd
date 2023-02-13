module ClockingWiz (
    input wire CLK100MHZ,
    input wire resetn,

    output wire cpu_clock,
    output wire bram_clock,
    output wire reset
);
    wire locked;
    clk_wiz_0 c_wiz(
        .clk_in1(CLK100MHZ), .clk_out1(bram_clock), .clk_out2(cpu_clock),
        .resetn(resetn), .locked
    );

    wire rn;
    proc_sys_reset_0 rst_wiz(
        .slowest_sync_clk(cpu_clock), .ext_reset_in(resetn),
        .dcm_locked(locked), .peripheral_aresetn(rn),
        .aux_reset_in(~resetn), .mb_debug_sys_rst(~resetn),
        .mb_reset(), .bus_struct_reset(), .peripheral_reset(),
        .interconnect_aresetn()
    );

    assign reset = ~rn;
endmodule

module Board #(
    CLK_PER_SEC = 40000000,
    BAUD_RATE = 200000
) (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    // input wire resetn,
    input wire UART_TXD_IN,
    output wire UART_RXD_OUT,
    // output wire [15:0] LED,
    // input wire [15:0] SW,

    // DDR2
    output wire [12:0] ddr2_addr,
    output wire [2:0] ddr2_ba,
    output wire ddr2_cas_n,
    output wire [0:0] ddr2_ck_n,
    output wire [0:0] ddr2_ck_p,
    output wire [0:0] ddr2_cke,
    output wire ddr2_ras_n,
    output wire ddr2_we_n,
    inout  wire [15:0] ddr2_dq,
    inout  wire [1:0] ddr2_dqs_n,
    inout  wire [1:0] ddr2_dqs_p,
    output wire [0:0] ddr2_cs_n,
    output wire [1:0] ddr2_dm,
    output wire [0:0] ddr2_odt
);
    localparam CLK_PER_HALF_BIT = CLK_PER_SEC / (2 * BAUD_RATE);

    wire clock, mig_clock, reset;
    ClockingWiz w(.CLK100MHZ, .resetn(CPU_RESETN), .cpu_clock(clock), .bram_clock(mig_clock), .reset);

    wire rxd = UART_TXD_IN;
    wire txd;
    assign UART_RXD_OUT = txd;

    // UARTの宣言
    wire rx_ready;
    wire [7:0] rdata;
    wire ferr;
    UartRx #(CLK_PER_HALF_BIT) uart_rx(clock, reset, rxd, rx_ready, rdata, ferr);

    wire tx_start;
    wire [7:0] sdata;
    wire tx_busy;
    UartTx #(CLK_PER_HALF_BIT) uart_tx(clock, reset, txd, tx_start, sdata, tx_busy);

    // BootLoaderの宣言
    wire instr_ready;
    wire data_ready;
    wire [31:0] content;
    wire program_loaded;
    wire w_tx_start1;
    wire [7:0] w_sdata1;
    BootLoader boot_loader(
        clock, reset, rx_ready, rdata, tx_busy, w_tx_start1, w_sdata1,
        instr_ready, data_ready, content, program_loaded
    );

    // 命令メモリの宣言
    IInstr instr_to_core();
    InstructionMemory instr_mem(
        .clock, .reset, .request(instr_to_core.slave),
        .push(instr_ready), .push_data(content)
    );

    // UARTの受信データを一時的に格納するバッファの宣言
    IRecvRequest recv_to_core();
    RingBuf tmp_recv_buf(
        .clock, .reset, .we(data_ready), .wd(content), .overflow(),
        .re(recv_to_core.en), .rd(recv_to_core.rd), .size(recv_to_core.size)
    );

    // キャッシュの宣言
    wire cpu_reset = ~program_loaded;
    ICache cache_core_bus();
    CoreCacheInterconnect conn(
        .clock, .mig_clock, .cpu_reset,
        .*, // DDR2
        .request(cache_core_bus.slave)
    );

    // BootLoaderとCoreのUARTの送信データを統合
    ISendRequest send_from_core();
    assign tx_start = w_tx_start1 | send_from_core.en;
    assign sdata = (w_tx_start1) ? w_sdata1 : send_from_core.content[7:0];
    assign send_from_core.busy = tx_busy;

    // コアの宣言
    DummyCore core(
        .clock, .reset(cpu_reset), .instr_mem(instr_to_core.master),
        .cache(cache_core_bus.master), .io_send(send_from_core.master),
        .io_recv(recv_to_core.master)
    );
endmodule
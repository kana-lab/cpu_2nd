// vivadoでブロックデザインを使う際のラッパー
// 最終的にブロックデザインは使わない事にしたので不要
module Top #(
    parameter CLK_PER_SEC = 40000000,
    parameter BAUD_RATE = 200000
) (
    input wire CLK100MHZ,
    input wire CPU_RESETN,
    input wire UART_TXD_IN,
    output wire UART_RXD_OUT,

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
    Board #(CLK_PER_SEC, BAUD_RATE) board(
        CLK100MHZ, CPU_RESETN, UART_TXD_IN, UART_RXD_OUT,
        ddr2_addr, ddr2_ba, ddr2_cas_n, ddr2_ck_n, ddr2_ck_p, ddr2_cke,
        ddr2_ras_n, ddr2_we_n, ddr2_dq, ddr2_dqs_n, ddr2_dqs_p, ddr2_cs_n,
        ddr2_dm, ddr2_odt
    );
endmodule
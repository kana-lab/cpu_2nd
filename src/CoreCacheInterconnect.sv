// キャッシュを構築する
// キャッシュとコアの仕様の違いを吸収する
module CoreCacheInterconnect (
    input wire clock,
    input wire mig_clock,
    input wire cpu_reset,

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
    output wire [0:0] ddr2_odt,

    ICache.slave request
);
    // stall中にwd, addrが保存されるようにする
    reg [31:0] wd_saved;
    reg [26:0] addr_saved;
    always_ff @(posedge clock) begin
        if (cpu_reset) begin
            wd_saved <= 0;
            addr_saved <= 0;
        end else if (request.en) begin
            wd_saved <= request.wd;
            addr_saved <= request.addr[26:0];
        end
    end
    wire [31:0] w_data = (request.en) ? request.wd : wd_saved;
    wire [26:0] addr = (request.en) ? request.addr[26:0] : addr_saved;

    // interfaces
    master_fifo master_fifo ();
    slave_fifo slave_fifo ();

    logic r_data_valid;  // dummy
    wire idle;

    // master
    cache_controller_idx12_w16 cache_controller_idx12_w16 (
        .wr(request.we),
        .w_data,
        .r_data(request.rd),
        .en(request.en),
        .addr,
        .r_data_valid(r_data_valid),
        .fifo(master_fifo),
        .cache_clk(clock),
        .idle(idle),
        .clk(clock)
    );

    assign request.stall = ~idle;

    // fifo
    dram_buf dram_buf (
        .master(master_fifo),
        .slave(slave_fifo)
    );

    // slave
    dram_controller dram_controller (
        // DDR2
        .*,
        // others
        .sys_clk(mig_clock),
        .fifo(slave_fifo)
    );
endmodule

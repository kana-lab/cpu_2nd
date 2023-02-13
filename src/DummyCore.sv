// instructionの先頭10個とdataの先頭10個を読み込み、
// UARTで送り返すダミーコア
module DummyCore (
    input wire clock,
    input wire reset,

    IInstr.master instr_mem,
    ICache.master cache,
    ISendRequest.master io_send,
    IRecvRequest.master io_recv
);
    reg [31:0] counter;
    reg [31:0] m[100:0];
    reg phase;

    assign instr_mem.addr = counter;
    assign io_recv.en = (counter <= 32'd10 || counter > 32'd20 || io_recv.size == 32'd0) ? 1'b0 : ~phase;
    // assign io_send.en = (io_send.busy == 1'b0 && counter < 32'd20) ? phase : 1'b0;
    // assign io_send.content = m[counter];
    
    always_ff @( posedge clock ) begin
        if (reset) begin
            counter <= 0;
            phase <= 0;
            io_send.en <= 0;
        end else begin
            if (io_send.en) io_send.en <= 0;

            if (~phase) begin
                if (counter <= 32'd10) begin
                    counter <= counter + 32'd1;
                    if (counter > 0) begin
                        m[counter - 32'd1] <= instr_mem.instr;
                    end
                end else if (counter <= 32'd20 && io_recv.size > 0) begin
                    counter <= counter + 32'd1;
                    m[counter - 32'd1] <= io_recv.rd;
                end else begin
                    phase <= 1'b1;
                    counter <= 0;
                end
            end else begin
                if (io_send.busy == 1'b0 && counter < 32'd20) begin
                    counter <= counter + 32'd1;
                    io_send.en <= 1'b1;
                    io_send.content <= m[counter];
                end
            end
        end
    end
endmodule
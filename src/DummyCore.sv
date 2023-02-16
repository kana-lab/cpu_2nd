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
    r32 counter;
    r32 m[100:0];
    reg phase;

    assign instr_mem.addr = counter;
    assign io_recv.en = (counter <= 'd10 || counter > 'd20 || io_recv.size == 'd0) ? 'b0 : ~phase;
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
                if (counter <= 'd10) begin
                    counter <= counter + 'd1;
                    if (counter > 0) begin
                        m[counter - 'd1] <= instr_mem.instr;
                    end
                end else if (counter <= 'd20) begin
                    if (io_recv.size > 0) begin
                        counter <= counter + 'd1;
                        m[counter - 'd1] <= io_recv.rd;
                    end
                end else begin
                    phase <= 'd1;
                    counter <= 0;
                end
            end else begin
                if (io_send.busy == 'd0 && counter < 'd20) begin
                    counter <= counter + 'd1;
                    // io_send.en <= 1'b1;
                    // io_send.content <= m[counter];
                    io_send.send(m[counter]);
                end
            end
        end
    end
endmodule
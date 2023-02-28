`include "typedefs.svh"

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
    reg phase, recv_valid;

    assign instr_mem.addr = counter;
    assign io_recv.en = (counter <= 'd10 || counter > 'd20 || io_recv.size == 'd0) ? 'b0 : ~phase;
    
    always_ff @( posedge clock ) begin
        recv_valid <= io_recv.en;

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
                    if (recv_valid) begin
                        m[counter - 'd1] <= io_recv.rd;
                        counter <= counter + 'd1;
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

// InstructionFetchを用いたダミーコア
module DummyCore2 (
    input wire clock,
    input wire reset,

    IInstr.master instr_mem,
    ICache.master cache,
    ISendRequest.master io_send,
    IRecvRequest.master io_recv
);
    BranchResult br;
    assign br.en = 0;
    wire stall = 0;
    w32 instr;
    Message #(IFResult) if_result();
    InstructionFetch instr_fetch (
        .clock, .reset, .stall, .branch_result(br), .instr_mem,
        // .instr_out(instr), .pc_out(), .approx_out()
        .if_result
    );
    assign instr = if_result.msg.instr;

    r32 m[100:0];
    reg phase, recv_valid;

    r32 counter;
    assign io_recv.en = (counter <= 'd10 || counter > 'd20 || io_recv.size == 'd0) ? 'b0 : ~phase;
    
    always_ff @( posedge clock ) begin
        recv_valid <= io_recv.en;

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
                        m[counter - 'd1] <= instr;
                    end
                end else if (counter <= 'd20) begin
                    if (recv_valid) begin
                        m[counter - 'd1] <= io_recv.rd;
                        counter <= counter + 'd1;
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
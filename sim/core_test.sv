`timescale 1ps/1ps
`include "../src/typedefs.svh"


module BramSim(
    input wire clock,
    input wire reset,

    IInstr.slave request
);
    (* ram_style = "block" *)reg [31:0] m[511:0];

    initial begin
        $readmemh("gcd.mem", m);
    end

    always_ff @( posedge clock ) begin
        request.instr <= m[request.addr];
    end
endmodule

module core_test;
    reg clock;
    always begin
        clock <= 0;
        #5;
        clock <= 1;
        #5;
    end

    reg reset;  // for top
    initial begin
        reset <= 1;
        #100;
        reset <= 0;
        #1000000;
        $finish();
    end

    IInstr instr_mem();
    BramSim bram_sim (.clock, .reset, .request(instr_mem.slave));

    ICache cache();
    assign cache.rd = 0;
    assign cache.rd = 0;
    ISendRequest io_send();
    assign io_send.busy = 0;
    IRecvRequest io_recv();
    assign io_recv.rd = 0;
    assign io_recv.size = 'd1;
    Core core (
        .clock, .reset, .instr_mem, .cache, .io_send, .io_recv
    );
endmodule
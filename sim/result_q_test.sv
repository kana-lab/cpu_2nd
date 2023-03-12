`timescale 1ps/1ps
`include "../src/typedefs.svh"
`include "../src/core/bus.svh"

module result_q_test;
    reg clock;
    always begin
        clock <= 0;
        #5;
        clock <= 'd1;
        #5;
    end

    reg reset;
    initial begin
        reset <= 'd1;
        #20;
        reset <= 0;
        #100;
        $finish();
    end

    Message #(Result) r_vec[1:0]();
    Message #(Result) complete_info();
    ResultQueue #(2) q (
        .clock, .flash(reset), .r_vec, .complete_info
    );

    assign complete_info.reject = 0;
    initial begin
        r_vec[0].msg <= Result'{'d1,0,0};
        r_vec[0].en <= 0;
        #25;
        r_vec[0].en <= 1;
        #10;
        r_vec[0].en <= 0;
    end

    initial begin
        r_vec[1].msg <= Result'{'d2,0,0};
        r_vec[1].en <= 0;
        #25;
        r_vec[1].en <= 1;
        #10;
        r_vec[1].en <= 0;
    end
endmodule
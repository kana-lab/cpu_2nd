`default_nettype wire
module fpu(
    input logic clk,
    input logic bram_clk,
    input logic [4:0] funct,
    input logic [31:0] x1,
    input logic [31:0] x2,
    output logic [31:0] y,
    // output logic [31:0] inst_y,
    input logic en, 
    output logic valid,
    output logic idle
);

    //logic add_ovf;
    logic add_idle, add_en, add_valid;
    logic [31:0] add_y;
    logic [4:0] funct_reg;
    always_ff @(posedge clk) begin
        if (en) funct_reg <= funct;
    end

    fadd_p fadd_p_i(
        .x1(x1),
        .x2(x2),
        .y(add_y),
        //.ovf(add_ovf),
        .clk(clk),
        .idle(add_idle),
        .en(add_en),
        .valid(add_valid)
    );


    logic sub_ovf;
    logic sub_idle, sub_en, sub_valid;
    logic [31:0] sub_y;


    fsub_p fsub_p_i(
        .x1(x1),
        .x2(x2),
        .y(sub_y),
//        .ovf(sub_ovf),
        .clk(clk),
        .idle(sub_idle),
        .en(sub_en),
        .valid(sub_valid)
    );

    logic mul_idle, mul_en, mul_valid;
    logic [31:0] mul_y;

    fmul_p fmul_p_i(
        .x1(x1),
        .x2(x2),
        .y(mul_y),
        .clk(clk),
        .idle(mul_idle),
        .en(mul_en),
        .valid(mul_valid)
    );


    logic div_idle, div_en, div_valid;
    logic [31:0] div_y;

    fdiv_p fdiv_p_i(
        .x1(x1),
        .x2(x2),
        .y(div_y),
        .clk(clk),
        .bram_clk(bram_clk),
        .idle(div_idle),
        .en(div_en),
        .valid(div_valid)
    );


    logic sqrt_idle, sqrt_en, sqrt_valid;
    logic [31:0] sqrt_y;

    fsqrt_p fsqrt_p(
        .x1(x2),//caution
        .y(sqrt_y),
        .clk(clk),
        .bram_clk(bram_clk),
        .idle(sqrt_idle),
        .en(sqrt_en),
        .valid(sqrt_valid)
    );
    
    logic ftoi_idle, ftoi_en, ftoi_valid;
    logic [31:0] ftoi_y;

    ftoi ftoi(
        .x1(x2),//caution
        .y(ftoi_y),
        .en(ftoi_en),
        .valid(ftoi_valid),
        .idle(ftoi_idle),
        .clk(clk)
    );
    logic itof_idle, itof_en, itof_valid;
    logic [31:0] itof_y;
    itof itof(
        .x1(x2),//caution
        .y(itof_y),
        .en(itof_en),
        .valid(itof_valid),
        .idle(itof_idle),
        .clk(clk)
    );
    
    // logic [31:0] feq_y;
    // logic feq_idle;
    // feq feq(
    //     .x1(x1s),
    //     .x2(x2),//caution
    //     .y(feq_y),
    //     .idle(feq_idle),
    //     .clk(clk)
    // );

    // logic [31:0] fless_y;
    // logic fless_idle;
    // fless fless(
    //     .x1(x1),
    //     .x2(x2),//caution
    //     .y(fless_y),
    //     .idle(fless_idle),
    //     .clk(clk)
    // );

    assign y = (funct_reg[4]==1'b1) ? ((funct_reg[3]==1'b1) ? sqrt_y :
                                    (funct_reg[2]==1'b1) ? itof_y :
                                    (funct_reg[1]==1'b1) ? ftoi_y : 32'b0) :
                (funct_reg[0]==1'b1) ? add_y :
                (funct_reg[1]==1'b1) ? sub_y :
                (funct_reg[2]==1'b1) ? mul_y :
                div_y;

    // assign inst_y = (funct[4]==1'b1) ? ((funct[0]==1'b1) ? fless_y : feq_y) : 1'b0;

    assign valid = (funct_reg[4]==1'b1) ? ((funct_reg[3]==1'b1) ? sqrt_valid :
                                    (funct_reg[2]==1'b1) ? itof_valid :
                                    (funct_reg[1]==1'b1) ? ftoi_valid : 1'b0) :
                (funct_reg[0]==1'b1) ? add_valid :
                (funct_reg[1]==1'b1) ? sub_valid :
                (funct_reg[2]==1'b1) ? mul_valid :
                div_valid;

    /*
    assign idle = (funct[4]==1'b1) ? ((funct[3]==1'b1) ? sqrt_idle :
                                    (funct[2]==1'b1) ? itof_idle :
                                    (funct[1]==1'b1) ? ftoi_idle : 
                                    (funct[0]==1'b1) ? fless_idle : feq_idle) :
                (funct[0]==1'b1) ? add_idle :
                (funct[1]==1'b1) ? sub_idle :
                (funct[2]==1'b1) ? mul_idle :
                div_idle;
    */
    assign idle = sqrt_idle & add_idle & sub_idle & mul_idle & div_idle & itof_idle & ftoi_idle;

    assign add_en = (funct[4]==1'b1) ? 1'b0:
                ((funct[0] == 1'b1) ? en : 1'b0);
    assign sub_en = (funct[4]==1'b1) ? 1'b0:
                (funct[1] == 1'b1) ? en : 1'b0;
    assign mul_en = (funct[4]==1'b1) ? 1'b0:
                (funct[2] == 1'b1) ? en : 1'b0;
    assign div_en = (funct[4]==1'b1) ? 1'b0:
                (funct[3] == 1'b1) ? en : 1'b0;
    
    assign sqrt_en = (funct[4]==1'b1) ? 
                    ((funct[3]==1'b1) ? en : 1'b0) : 1'b0;

    assign ftoi_en = (funct[4]==1'b1 && funct[1]==1'b1) ? en: 1'b0;
    assign itof_en = (funct[4]==1'b1 && funct[2]==1'b1) ? en: 1'b0;

    logic y_reg;
    always @(posedge clk) begin
        y_reg <= y;
    end


endmodule
`default_nettype wire
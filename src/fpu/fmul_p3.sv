`default_nettype none

module fmul_p (input wire [31:0]  x1,
             input wire [31:0]  x2,
             output logic [31:0] y,
             input wire clk,
             output logic idle,
             input wire en,
             output logic valid);

   wire [7:0] e1;
   wire [7:0] e2;
   //wire [22:0] m1;
   //wire [22:0] m2;
   wire  s1;
   wire  s2;

   assign e1 = x1[30:23];
   assign e2 = x2[30:23];
   //assign m1 = x1[22:0];
   //assign m2 = x2[22:0];
   assign s1 = x1[31];
   assign s2 = x2[31];

   wire [12:0] h1;
   wire [12:0] h2;
   wire [10:0] l1;
   wire [10:0] l2;

   assign h1 = {1'b1, x1[22:11]};
   assign h2 = {1'b1, x2[22:11]};
   assign l1 = x1[10:0];
   assign l2 = x2[10:0];

   logic [25:0] hh;
   logic [23:0] hl;
   logic [23:0] lh;
   //wire [21:0] ll;

   logic [8:0] e_tmp;
   logic s;

   logic [25:0] hh_hl_lh_half;

   logic [25:0] hh_hl_lh;
   logic [8:0] e_p1;
   assign e_p1 = e_tmp + 9'b1;
   //reg [22:0] m;
   //reg [7:0] e;
   assign hh = h1 * h2;
   assign hl = h1 * l2;
   //assign lh = l1 * h2;//
   assign hh_hl_lh = hh_hl_lh_half + (lh>>11) + 2; //round_up
   logic [31:0] x1_reg, x2_reg;

   wire [22:0] m;
   assign m = (hh_hl_lh[25]==1'b1) ? hh_hl_lh[24:2] : hh_hl_lh[23:1];

   wire [7:0] e;
   assign e = (hh_hl_lh[25]==1'b1) ? e_p1[7:0] : e_tmp[7:0];

   assign y = (x1_reg[30:0]!=31'b0 & x2_reg[30:0]!=31'b0) ? {s,e[7:0],m} : 32'b0;

    enum logic [2:0] {
        STATE1,
        STATE2,
        STATE3
    } state = STATE1;

   always @(posedge clk) begin
    if(state == STATE1) begin
        valid <= 1'b0;
        if (en == 1'b1) begin
            x1_reg <= x1;
            x2_reg <= x2;
            //hh <= h1 * h2;
            //hl <= h1 * l2;
            hh_hl_lh_half <= hh + (hl>>11);
            //hh_hl_lh <= hh + (hl>>11) + (lh>>11) + 2; //round_up
            lh <= l1 * h2;
            e_tmp <= {1'b0, e1} + {1'b0, e2} + 9'd129;
            s <= s1 ^ s2;
            idle <= 1'b0;
            state <= STATE2;
        end else begin
            idle <= 1'b1;
        end
    end else if(state == STATE2) begin
        //e_p1 <= e_tmp + 9'b1;
        //y <= (x1_reg[30:0]!=31'b0 & x2_reg[30:0]!=31'b0) ? {s,e[7:0],m} : 32'b0;
        valid <= 1'b1;
        idle <= 1'b1;
        state <= STATE1;
    end
   end
endmodule
/*
   wire [7:0] e1;
   wire [7:0] e2;
   //wire [22:0] m1;
   //wire [22:0] m2;
   wire  s1;
   wire  s2;

   assign e1 = x1[30:23];
   assign e2 = x2[30:23];
   //assign m1 = x1[22:0];
   //assign m2 = x2[22:0];
   assign s1 = x1[31];
   assign s2 = x2[31];

   wire [12:0] h1;
   wire [12:0] h2;
   wire [10:0] l1;
   wire [10:0] l2;

   assign h1 = {1'b1, x1[22:11]};
   assign h2 = {1'b1, x2[22:11]};
   assign l1 = x1[10:0];
   assign l2 = x2[10:0];

   logic [25:0] hh;
   logic [23:0] hl;
   logic [23:0] lh;
   //wire [21:0] ll;

   logic [8:0] e_tmp;
   logic s;
   assign s = s1 ^ s2; 
    assign e_tmp = {1'b0, e1} + {1'b0, e2} + 9'd129;
   logic [25:0] hh_hl_lh_half;

   logic [25:0] hh_hl_lh;
   logic [8:0] e_p1;
   assign e_p1 = e_tmp + 9'b1;

   assign hh = h1 * h2;
   assign hl = h1 * l2;
   assign lh = l1 * h2;//
   assign hh_hl_lh = hh + (hl>>11) + + (lh>>11) + 2; //round_up
   logic [31:0] x1_reg, x2_reg;

   logic [22:0] m;
   assign m = (hh_hl_lh[25]==1'b1) ? hh_hl_lh[24:2] : hh_hl_lh[23:1];

   logic [7:0] e;
   assign e = (hh_hl_lh[25]==1'b1) ? e_p1[7:0] : e_tmp[7:0];

   //assign y = (x1[30:0]!=31'b0 & x2[30:0]!=31'b0) ? {s,e[7:0],m} : 32'b0;

    enum logic [2:0] {
        STATE1,
        STATE2,
        STATE3
    } state = STATE1;

   //Stage1
   always @(posedge clk) begin
    if(state == STATE1) begin
        valid <= 1'b0;
        if (en == 1'b1) begin
            y <= (x1[30:0]!=31'b0 & x2[30:0]!=31'b0) ? {s,e[7:0],m} : 32'b0;
            state <= STATE2;
        end else begin
            idle <= 1'b1;
        end
    end else if(state == STATE2) begin
        //e_p1 <= e_tmp + 9'b1;
        //y <= (x1_reg[30:0]!=31'b0 & x2_reg[30:0]!=31'b0) ? {s,e[7:0],m} : 32'b0;
        valid <= 1'b1;
        idle <= 1'b1;
        state <= STATE1;
    end
   end
endmodule
*/
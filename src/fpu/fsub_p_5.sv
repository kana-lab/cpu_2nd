`default_nettype none

module fsub_p (input wire [31:0]  x1,
             input wire [31:0]  x2,
             output logic  [31:0] y,
             input wire clk,
             output logic valid,
             output logic idle,
             input wire en);
   
    enum logic [2:0] {
        STATE1,
        STATE2,
        STATE3
    } state = STATE1;

   logic ovf;
   wire [7:0] e1_w;
   wire [7:0] e2_w;
   wire [22:0] m1_w;
   wire [22:0] m2_w;
   wire  s1_w;
   wire  s2_w;

   wire [7:0] e1;
   wire [7:0] e2;
   wire [22:0] m1;
   wire [22:0] m2;
   wire  s1;
   wire  s2;

   assign e1_w = x1[30:23];
   assign e2_w = x2[30:23];
   assign m1_w = x1[22:0];
   assign m2_w = x2[22:0];
   assign s1_w = x1[31];
   assign s2_w = ~x2[31];

   reg [31:0] x1_reg, x2_reg;

   assign e1 = x1_reg[30:23];
   assign e2 = x2_reg[30:23];
   assign m1 = x1_reg[22:0];
   assign m2 = x2_reg[22:0];
   assign s1 = x1_reg[31];
   assign s2 = ~x2_reg[31];

   wire [24:0] m1a;
   wire [24:0] m2a;
   wire [7:0] e1a;
   wire [7:0] e2a;

   reg [7:0] e1a_reg;
   reg [7:0] e2a_reg;

   wire [7:0] e2ai;

   wire [8:0] te;

   wire [7:0] tde;
   wire [0:0] ce;
   wire [8:0] te_1;
   wire [8:0] te_n;

   wire [4:0] de;

   wire sel;

   reg [24:0] ms;
   //reg [24:0] mi;
   wire [24:0] mi;
   assign mi = (sel == 1'b0) ? m2a : m1a;
   reg [7:0] es;
   reg [7:0] ei;
   reg [0:0] ss;

   assign m1a = (e1_w=='0) ? {2'b00,m1_w[22:0]} : {2'b01,m1_w[22:0]};
   assign m2a = (e2_w=='0) ? {2'b00,m2_w[22:0]} : {2'b01,m2_w[22:0]};

   assign e1a = (e1_w=='0) ? 8'b1 : e1_w;
   assign e2a = (e2_w=='0) ? 8'b1 : e2_w;

   assign e2ai = ~e2a;

   assign te = {1'b0,e1a}+{1'b0,e2ai};

   assign te_1 = te + 1;
   assign te_n = ~te;

   assign ce = (te[8]==1) ? 1'b0 : 1'b1;
   assign tde = (te[8]==1) ? te_1[7:0] : te_n[7:0];


   assign de = (|(tde[7:5])) ? 5'd31 : tde[4:0];

   assign sel = (de == 0) ? ((m1a > m2a) ? 1'b0 : 1'b1) : ce;

   wire [55:0] mie;

   reg [55:0] mia;

   wire tstck;

   wire [26:0] mye;

   wire [7:0] esi;

   reg [7:0] eyd;
   reg [26:0] myd;
   reg stck;
   reg ovf_f1;

   reg [4:0] se;


   assign mie = {mi,31'b0};

   //assign mia = mie >> de;
//stage2 from
   assign tstck = |(mia[28:0]);
//here stage1 is better?

   assign mye = (s1 == s2) ? {ms,2'b00} + mia[55:29] : {ms,2'b00} - mia[55:29];

   assign esi = es + 1;

   ///
   wire [26:0] myd_w;
   wire [4:0] se_w;
   assign myd_w = (mye[26] == 0) ? mye : ((esi == 8'd255) ? {2'b01,25'b0} : mye >> 1'b1);

   assign se_w = (myd_w[25]==1'b1) ? 5'd0 : 
               ((myd_w[24]==1'b1) ? 5'd1 : 
               ((myd_w[23]==1'b1) ? 5'd2 : 
               ((myd_w[22]==1'b1) ? 5'd3 : 
               ((myd_w[21]==1'b1) ? 5'd4 : 
               ((myd_w[20]==1'b1) ? 5'd5 : 
               ((myd_w[19]==1'b1) ? 5'd6 :
               ((myd_w[18]==1'b1) ? 5'd7 :
               ((myd_w[17]==1'b1) ? 5'd8 :
               ((myd_w[16]==1'b1) ? 5'd9 :
               ((myd_w[15]==1'b1) ? 5'd10 :
               ((myd_w[14]==1'b1) ? 5'd11 :
               ((myd_w[13]==1'b1) ? 5'd12 :
               ((myd_w[12]==1'b1) ? 5'd13 :
               ((myd_w[11]==1'b1) ? 5'd14 :
               ((myd_w[10]==1'b1) ? 5'd15 :
               ((myd_w[9]==1'b1) ? 5'd16 : 
               ((myd_w[8]==1'b1) ? 5'd17 :
               ((myd_w[7]==1'b1) ? 5'd18 :
               ((myd_w[6]==1'b1) ? 5'd19 :
               ((myd_w[5]==1'b1) ? 5'd20 :
               ((myd_w[4]==1'b1) ? 5'd21 :
               ((myd_w[3]==1'b1) ? 5'd22 :
               ((myd_w[2]==1'b1) ? 5'd23 :
               ((myd_w[1]==1'b1) ? 5'd24 :
               ((myd_w[0]==1'b1) ? 5'd25 : 5'd26)))))))))))))))))))))))));

//from here stage3

   wire [8:0] eyf;

   wire [7:0] eyr;
   wire [26:0] myf;

   wire [24:0] myr;

   wire [7:0] eyri;

   wire [7:0] ey;
   wire [22:0] my;
   wire ovf_f2;

   wire sy;

   wire nzm1;
   wire nzm2;

   assign eyf = {1'b0, eyd} - {4'b0 ,se};

   assign eyr = ($signed(eyf) > 0) ? eyf[7:0] : 8'b0;
   assign myf = ($signed(eyf) > 0) ? myd << se : myd << (eyd[4:0] - 1);
/*
   assign myr = ((myf[1]==1 && myf[0]==0 && stck==0 && myf[2]==1)
               || (myf[1]==1 && myf[0]==0 && s1==s2 && stck==1)
               || (myf[1]==1 && myf[0]==1)) ? myf[26:2] + 25'b1 : myf[26:2];
*/
   assign myr = myf[26:2];
   
   assign eyri = eyr[7:0] + 8'b1;

   assign ey = (myr[24]==1) ? eyri : ((myr[23:0]==0) ? 8'b0 : eyr);
   assign my = (myr[24]==1) ? 23'b0 : ((myr[23:0]==0) ? 23'b0 : myr[22:0]);
   //assign ovf_f2 = (myr[24]==1) ? ((eyri==8'd255) ? 1'b1 : 1'b0) : 1'b0; 
   
   assign sy = ((ey==0) && (my==0)) ? (s1 && s2) : ss;

   //assign y = {sy,ey,my};

   always_ff @(posedge clk) begin
      if (state==STATE1) begin
         if (en == 1'b1) begin
            if (sel==1'b0) begin
                ms <= m1a;
                //mi <= m2a;
                es <= e1a;
                ei <= e2a;
                ss <= s1_w;
            end else begin
                ms <= m2a;
                //mi <= m1a;
                es <= e2a;
                ei <= e1a;
                ss <= s2_w;
            end
            x1_reg <= x1;
            x2_reg <= x2;
            idle <= 1'b0;
            state <= STATE2;
            e1a_reg <= e1a;
            e2a_reg <= e2a;
            mia <=  mie >> de;
         end else begin
            idle <= 1'b1;
            valid <= 1'b0;
         end

      end else if(state == STATE2) begin
        if(mye[26]==0) begin
            eyd <= es;
            myd <= mye;
            stck <= tstck;
        end else begin
            eyd <= esi;
            myd <= mye >>1'b1;
            stck <= tstck || mye[0];
        end
        se <= se_w;
        state<=STATE3;
      end else if(state==STATE3) begin
        valid <= 1'b1;
        idle <= 1'b1;
        y <= {sy,ey,my};
        state <= STATE1;
      end
   end

endmodule

`default_nettype wire
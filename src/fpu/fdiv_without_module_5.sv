module fdiv_p (input wire [31:0]  x1,
            input logic [31:0] x2,
             input logic clk,
             input logic bram_clk,
             output logic [31:0] y,
             input logic en,
             output logic valid,
             output logic idle);
    
    logic not_zero_exception;

    wire [7:0] e1;
    wire [22:0] m1;
    wire  s1;

    assign e1 = x1[30:23];
    assign m1 = x1[22:0];
    assign s1 = x1[31];

    wire [7:0] e2;
    wire [22:0] m2;
    wire  s2;

    assign e2 = x2[30:23];
    assign m2 = x2[22:0];
    assign s2 = x2[31];
    
    logic [9:0] index;

    assign wea_f = 1'b0;//read
    assign ena_f = 1'b1;
    assign index = x2[22:13];

    (* ram_style = "BLOCK" *)reg [63:0] bram_for_div_ab [0:1023];

    initial begin
        $readmemb("inv_ab64_ram.mem", bram_for_div_ab, 0, 1023);
    end

    logic [63:0] Q_ab;
    logic [31:0] Q_a;//grad
    logic [31:0] Q_b;//intercept

    assign Q_a = Q_ab[63:32];
    assign Q_b = Q_ab[31:0];
    
    logic [7:0] inv_e;
    logic inv_s;
    logic [7:0] e1_reg, e2_reg;
    logic [22:0] m1_reg, m2_reg;
    logic  s1_reg, s2_reg;
    logic [12:0] h1;
    logic [12:0] h2;
    logic [10:0] l1;
    logic [10:0] l2;
    logic [25:0] hh;
    logic [23:0] hl;
    logic [23:0] lh;

    logic [25:0] hh_hl_lh;
    assign h1 = {1'b1, m2_reg[22:11]};
    assign h2 = {1'b1, Q_a[22:11]};
    assign l1 = m2_reg[10:0];
    assign l2 = Q_a[10:0];
    /*
    assign hh = h1 * h2;
    assign hl = h1 * l2;
    assign lh = l1 * h2;
    */
    assign hh_hl_lh = hh + (hl>>11) + (lh>>11) + 2;

    logic [22:0] tmp_m;
    assign tmp_m = (hh_hl_lh[25]==1'b1) ? hh_hl_lh[24:2] : hh_hl_lh[23:1];
    logic [24:0] inv_m_plus;
    logic [22:0] inv_m;
    assign inv_m_plus = {1'b1,Q_b[22:0],1'b0} - {2'b01,tmp_m[22:0]};
    assign inv_m = {inv_m_plus[22:0]};

    logic [31:0] inv_y;


    logic [12:0] h1_2;
    logic [12:0] h2_2;
    logic [10:0] l1_2;
    logic [10:0] l2_2;
    logic [25:0] hh_2;
    logic [23:0] hl_2;
    logic [23:0] lh_2;
    logic [25:0] hh_hl_lh_2;
    assign h1_2 = {1'b1, m1_reg[22:11]};
    assign h2_2 = {1'b1, inv_y[22:11]};
    assign l1_2 = m1_reg[10:0];
    assign l2_2 = inv_y[10:0];
    /*
    assign hh_2 = h1_2 * h2_2;
    assign hl_2 = h1_2 * l2_2;
    assign lh_2 = l1_2 * h2_2;
    */
    assign hh_hl_lh_2 = hh_2 + (hl_2>>11) + (lh_2>>11) + 2;
    logic [8:0] e_tmp;
    assign e_tmp = {1'b0, e1_reg} + {1'b0, inv_y[30:23]} + 9'd129;
    logic s;
    assign s = s1_reg ^ inv_y[31]; 
    logic [8:0] e_p1;
    assign e_p1 = e_tmp + 9'b1;
    logic [7:0] e;
    assign e = (hh_hl_lh_2[25]==1'b1) ? e_p1[7:0] : e_tmp[7:0];

    logic [22:0] m;
    assign m =  (hh_hl_lh_2[25]==1'b1) ? hh_hl_lh_2[24:2] : hh_hl_lh_2[23:1];


    assign y = (not_zero_exception == 1'b1) ? {s,e,m} : 32'b0;
   
   //assign ovf = (e[8]==1'b0) ? 1'b0 : 1'b1;
    enum logic [2:0] {
        STATE1,
        STATE2,
        STATE3,
        STATE4,
        STATE5,
        STATE6,
        STATE7
    } state = STATE1;
    enum logic [2:0] {
        B_STATE1,
        B_STATE2,
        B_STATE3,
        B_STATE4
    } bram_state = B_STATE1;

    always @(posedge clk) begin
        if(state == STATE1) begin
            valid <= 1'b0;
            if (en == 1'b1) begin
                m1_reg <= m1;
                e1_reg <= e1;
                s1_reg <= s1;
                m2_reg <= m2;
                e2_reg <= e2;
                s2_reg <= s2;
                inv_e <=  8'b11111101 - e2;
                inv_s <= s2;
                not_zero_exception <= (x1[30:0]!=31'b0 & x2[30:0]!=31'b0);
                state <= STATE2;
                idle <= 1'b0;
            end else begin
                idle <= 1'b1;
            end
        end else if(state == STATE2) begin
            hh <= h1 * h2;
            hl <= h1 * l2;
            lh <= l1 * h2;
            state <= STATE3;
        end else if(state == STATE3) begin
            inv_y <= {inv_s,inv_e,inv_m};
            state <= STATE4;
        end else if(state == STATE4) begin
            //idle <= 1'b1;
            hh_2 <= h1_2 * h2_2;
            hl_2 <= h1_2 * l2_2;
            lh_2 <= l1_2 * h2_2;
            //hh_hl_lh_2 <= hh_2 + (hl_2>>11) + (lh_2>>11) + 2;
            state <= STATE5;
        end else if(state == STATE5) begin
            valid <= 1'b1;
            state <= STATE1;
            idle <= 1'b1;
        end
    end
    always @(posedge clk)begin
        Q_ab <= bram_for_div_ab[index];
    end
endmodule
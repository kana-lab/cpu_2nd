module fsqrt_p (input wire [31:0]  x1,
             input logic clk,
             input logic bram_clk,
             output logic [31:0] y,
             input logic en,
             output logic valid,
             output logic idle);

    wire [7:0] e1;
    wire [22:0] m1;
    wire  s1;

    assign e1 = x1[30:23];
    assign m1 = x1[22:0];
    assign s1 = x1[31];
    
    logic [8:0] index_m;
    assign index_m = m1[22:14];
    logic index_e;
    assign index_e = ~e1[0];
    logic [9:0] index;
    assign index = {index_e,index_m};

    (* ram_style = "BLOCK" *)reg [63:0] bram_for_sqrt_ab [0:1023];
    initial begin
        $readmemb("sqrt_ab64_ram.mem", bram_for_sqrt_ab, 0, 1023);
    end

    logic [63:0] Q_ab;
    logic [31:0] Q_a;//grad
    logic [31:0] Q_b;//intercept

    assign Q_a = Q_ab[63:32];
    assign Q_b = Q_ab[31:0];

////2nd clk   
    logic [7:0] e1_reg;
    logic [22:0] m1_reg;
    logic  s1_reg;
    logic [12:0] h1;
    logic [12:0] h2;
    logic [10:0] l1;
    logic [10:0] l2;
    logic [25:0] hh;
    logic [23:0] hl;
    logic [23:0] lh;
    logic [25:0] hh_hl_lh;
    assign h1 = {1'b1, m1_reg[22:11]};
    assign h2 = {1'b1, Q_a[22:11]};
    assign l1 = m1_reg[10:0];
    assign l2 = Q_a[10:0];

    assign hh_hl_lh = hh + (hl>>11) + (lh>>11) + 2;

////1st clk
    wire [8:0] e_tmp;
    logic [8:0] e_tmp_reg;
    //index of a has 2 pattern
    assign e_tmp = (e1[0] == 1'b1) ? {1'b0, 8'b01111111} + {1'b0, 8'b01111101} + 9'd129 : {1'b0, 8'b10000000} + {1'b0, 8'b01111101} + 9'd129;
    wire [8:0] e_p1;
    logic [8:0] e_p1_reg;
    assign e_p1 = e_tmp + 9'b1;

////2nd clk
    logic [7:0] tmp_e;//index of a*x(0.49~0.25 * 1~3.99)   use for checking if unf(b + a*x =0.999)
    assign tmp_e = (hh_hl_lh[25]==1'b1) ? e_p1_reg[7:0] : e_tmp_reg[7:0];

    logic [22:0] tmp_m;
    assign tmp_m = (hh_hl_lh[25]==1'b1) ? hh_hl_lh[24:2] : hh_hl_lh[23:1];

    logic [24:0] sqrt_m_plus;
    logic [22:0] sqrt_m;
    //b + ax
    assign sqrt_m_plus = (tmp_e[0] == 1'b0) ? {1'b1,Q_b[22:0]} + {1'b1,tmp_m} : (tmp_e[1] == 1'b0) ? {1'b1,Q_b[22:0]} + {1'b1,tmp_m[22:1]} : {1'b1,Q_b[22:0]} + {tmp_m[22:0],1'b1};
    //assign sqrt_m = (sqrt_m_plus[24] == 1'b1) ? sqrt_m_plus[23:1] : sqrt_m_plus[22:0];
    assign sqrt_m = sqrt_m_plus[23:1];

    logic [7:0] sqrt_e;
    assign sqrt_e  = (e1_reg[0]==1'b1) ? (8'b01111110 + 8'b1) + ((e1_reg+1)>>1) - 8'd64 : (8'b01111110 + 1'b1) + (e1_reg>>1)-8'd64;

    assign y = {s1_reg, sqrt_e, sqrt_m};

    enum logic [1:0] {
        STATE1,
        STATE2,
        STATE3,
        STATE4
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

                e_tmp_reg <= e_tmp;
                e_p1_reg <= e_p1;
                state <= STATE2;
                idle <= 1'b0;
            end else begin
                idle <= 1'b1;
            end
        end else if(state == STATE2) begin
            hh <= h1 * h2;
            hl <= h1 * l2;
            lh <= l1 * h2;
            //idle <= 1'b1;
            state <= STATE3;
        end else if(state == STATE3) begin
            //y <= {s1_reg, sqrt_e, sqrt_m};//
            valid <= 1'b1;
            state <= STATE1;
            idle <= 1'b1;
        end
    end

    always @(posedge clk)begin
        Q_ab <= bram_for_sqrt_ab[index];
    end


endmodule
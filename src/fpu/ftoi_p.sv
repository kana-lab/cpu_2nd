`default_nettype wire

module ftoi(
    input logic [31:0] x1,
    output logic [31:0] y,
    input logic en,
    output logic valid,
    output logic idle,
    input logic clk
);

   wire [7:0] e1;
   wire [22:0] m1;
   wire  s1;
   logic s1_reg;

   assign e1 = x1[30:23];
   assign m1 = x1[22:0];
   assign s1 = x1[31];

   wire [30:0] temp_d;
   wire [30:0] after_d;
   logic [30:0] after_d_reg;
   assign temp_d = {1'b1, m1, 7'b0};

   wire [7:0] shift;
   assign shift = 8'd30 - (e1 - 8'b01111111);

   wire [7:0] round_bit_index;
   wire round_bit;
   logic round_bit_reg;
   assign round_bit_index = shift -8'b1;
   assign round_bit = (round_bit_index < 0 || round_bit_index > 30) ? 1'b0 : temp_d[round_bit_index];
   
   
   assign after_d = (shift < 0) ? temp_d : temp_d >> shift;
   
   wire [31:0] unsigned_y;
   assign unsigned_y = (round_bit_reg==1) ? {1'b0, after_d_reg} + 1'b1 : {1'b0,after_d_reg};

   //assign y = (s1_reg == 1'b0) ? unsigned_y : -unsigned_y;
   enum logic [2:0] {
        STATE1,
        STATE2,
        STATE3
    } state = STATE1;

    always @(posedge clk) begin
        if(state == STATE1)begin
            valid <= 1'b0;
            if(en == 1'b1)begin
                round_bit_reg <= round_bit;
                after_d_reg <= after_d;
                s1_reg <= s1;
                idle <= 1'b0;//
                state <= STATE2;
            end else begin
                idle <= 1'b1;
            end
        end else if(state == STATE2) begin
            idle <= 1'b1;
            valid <= 1'b1;
            y <= (s1_reg == 1'b0) ? unsigned_y : -unsigned_y;
            state <= STATE1;
        end
    end
endmodule
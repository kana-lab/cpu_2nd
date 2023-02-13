`default_nettype wire

module itof(
    input logic [31:0] x1,
    output logic [31:0] y,
    input logic en,
    output logic valid,
    output logic idle,
    input logic clk
);

logic zero_exception;
wire x_s;
logic x_s_reg;
assign x_s = x1[31];

wire [31:0] abs_x1;
logic [31:0] abs_x1_reg;
assign abs_x1 = (x_s==1'b1) ? -x1 : x1;

wire [4:0] kechi_bit_index;

assign kechi_bit_index = abs_x1[31] ? 5'd31:
                         abs_x1[30] ? 5'd30:
                         abs_x1[29] ? 5'd29:
                         abs_x1[28] ? 5'd28:
                         abs_x1[27] ? 5'd27:
                         abs_x1[26] ? 5'd26:
                         abs_x1[25] ? 5'd25:
                         abs_x1[24] ? 5'd24:
                         abs_x1[23] ? 5'd23:
                         abs_x1[22] ? 5'd22:
                         abs_x1[21] ? 5'd21:
                         abs_x1[20] ? 5'd20:
                         abs_x1[19] ? 5'd19:
                         abs_x1[18] ? 5'd18:
                         abs_x1[17] ? 5'd17:
                         abs_x1[16] ? 5'd16:
                         abs_x1[15] ? 5'd15:
                         abs_x1[14] ? 5'd14:
                         abs_x1[13] ? 5'd13:
                         abs_x1[12] ? 5'd12:
                         abs_x1[11] ? 5'd11:
                         abs_x1[10] ? 5'd10:
                         abs_x1[9] ? 5'd9:
                         abs_x1[8] ? 5'd8:
                         abs_x1[7] ? 5'd7:
                         abs_x1[6] ? 5'd6:
                         abs_x1[5] ? 5'd5:
                         abs_x1[4] ? 5'd4:
                         abs_x1[3] ? 5'd3:
                         abs_x1[2] ? 5'd2:
                         abs_x1[1] ? 5'd1:5'd0;

logic [4:0] kechi_bit_index_reg;

wire [31:0] shifted_abs_x1;
assign shifted_abs_x1 = abs_x1_reg << (6'd32 - {1'b0,kechi_bit_index_reg});

wire [22:0] m;
wire [7:0] e;
assign m = (shifted_abs_x1[8]==1'b1) ? shifted_abs_x1[31:9] + 22'b1 : shifted_abs_x1[31:9];
assign e = (shifted_abs_x1[31:9]==23'b11111111111111111111111) ? 8'b10000000 + kechi_bit_index_reg : 8'b01111111 + kechi_bit_index_reg;

//assign y = (zero_exception) ? 32'b0 : {x_s, e, m};

enum logic [2:0] {
    STATE1,
    STATE2,
    STATE3
} state = STATE1;

always @(posedge clk) begin
    if(state == STATE1)begin
        valid <= 1'b0;
        if(en == 1'b1)begin
            kechi_bit_index_reg <= kechi_bit_index;
            abs_x1_reg <= abs_x1;
            zero_exception <= (x1==32'b0);
            x_s_reg <= x_s;
            idle <= 1'b0;
            state <= STATE2;
        end else begin
            idle <= 1'b1;
        end
    end else if(state == STATE2) begin
        idle <= 1'b1;
        valid <= 1'b1;
        y <= (zero_exception) ? 32'b0 : {x_s_reg, e, m};
        state <= STATE1;
    end
end

endmodule
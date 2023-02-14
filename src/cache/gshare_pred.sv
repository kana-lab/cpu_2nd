/*
interface IPredictor;
    wire pred_en;
    wire [14:0] pred_pc;
    wire pred_taken;
    
    wire rslt_en;
    wire [14:0] rslt_pc;
    wire rslt_taken;
    
    modport master (
        input pred_taken,
        output pred_en, pred_pc, rslt_en, rslt_pc, rslt_taken
    );
    
    modport slave (
        input pred_en, pred_pc, rslt_en, rslt_pc, rslt_taken,
        output pred_taken
    );
endinterface
*/


module GSharePredictor (
    input logic clk,
    IPredictor.slave predict
);
    parameter LEN = 8;//history_len

    reg [1:0] pht [0:2**LEN-1];//2bit counter
    reg [LEN-1:0] g_h = 'b0;//gloabl_history

//init pht
    initial begin
        $readmemh("gshare_ram.mem", pht, 0, 2**LEN-1);
    end

    logic [LEN-1:0] index;

    assign index = g_h ^ predict.pred_pc[14:14-LEN+1];

    logic [1:0] cnt;

    assign cnt = pht[index];

    assign predict.pred_taken = (cnt >= 2) ? 1'b1 : 1'b0;

    logic [LEN-1:0] rslt_index;
    logic [LEN-1:0] pred_history;

    //assign rslt_index = pred_history ^ predic.rslt_pc[14:14-LEN+1];

//memorize temp g_h
    always @(posedge clk) begin
        if(predict.pred_en)begin
            //pred_history <= g_h;
            rslt_index <= index;
        end
    end

//update g_h
    always @(posedge clk) begin
        if(predict.rslt_en)begin
            g_h <= {g_h[LEN-2:0],predict.rslt_taken};
        end
    end

//update pht
    always @(posedge clk) begin
        if(predict.rslt_en)begin
            if(predict.rslt_taken == 1'b1)begin
                pht[rslt_index] <= (pht[rslt_index] == 2'b11) ? 2'b11 : pht[rslt_index] + 1;
            end else begin
                pht[rslt_index] <= (pht[rslt_index] == 2'b00) ? 2'b00 : pht[rslt_index] - 1;
            end
        end
    end    





    
endmodule
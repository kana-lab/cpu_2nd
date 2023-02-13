//success
//init-write00-11 cache_clk tag:2
//address-byte
//000000000       00    000000000000   0000
//.9 fixed 0      tag:2 idx:12         offset:4
//pmt 18
//  0     0     0    0  0  0 000000000
// vd11  vd10  vd01 vd00  v  d tag:9
//hit:3clk(judge if hit in 2 clk)
//miss:about 59clk
module cache_controller_idx12_w16(
    input wire clk,
    input wire wr,//1:write,0:read
    input logic [31:0] w_data,
    output logic [31:0] r_data,

    input wire en,
    input wire [26:0] addr,
    output logic r_data_valid,
    input wire cache_clk,
    output logic idle,
    output logic [1:0] hit,
    master_fifo.master fifo
);

    parameter WS = 32;//wordsize
    parameter TAGMSB = 24;
    parameter TAGLSB = 16;
    parameter IDXMSB = 15;
    parameter IDXLSB = 4;
    parameter OFSMSB = 3;
    parameter OFSLSB = 0;

    parameter TAGSIZE = 9;
    parameter IDXSIZE = 12;
    parameter OFSSIZE = 4;
    
    parameter DEPTH = 4096;
    parameter LINESIZE = 16;
    
    parameter PMTSIZE = 18;//changed
    parameter DIRTYBIT = 9;
    parameter VALIDBIT = 10;
    parameter VD00BIT = 11;
    parameter VD01BIT = 12;
    parameter VD10BIT = 13;
    parameter VD11BIT = 14;

    logic        ena_p, enb_p;
    logic        wea_p, web_p;
    logic [IDXSIZE-1:0] addra_p, addrb_p;
    logic [PMTSIZE-1:0]  dina_p, dinb_p;
    logic [PMTSIZE-1:0]  douta_p, doutb_p;

    logic        ena_c, enb_c;
    logic        wea_c, web_c;
    logic [IDXSIZE-1:0] addra_c, addrb_c;
    logic [LINESIZE*32-1:0]  dina_c, dinb_c;
    logic [LINESIZE*32-1:0]  douta_c, doutb_c;

    logic [26:0] reading_addr;
    logic [26:0] writing_addr;
    logic [31:0] writing_data;
    //logic [1:0] hit;//hit 01 miss 10
    logic dirty;//dirty 1
    logic done;
    logic [TAGSIZE-1:0] dirty_tag;

    logic [127:0] r1, r2, r3, r4;
    logic rsp_4_ready;
    logic [127:0] chosen_r_data;
    logic [1:0] r_data_offset;
    logic [511:0] wb_data;
    logic wb;
    logic req_skip;

    logic now_start = 1'b0;
    //assign now_start = ((state == IDLE) && (en == 1'b1));
    
    logic [IDXSIZE-1:0] index;

    logic r_stage = 1'b0;

    logic [31:0] r_data_reg;


    
    assign fifo.clk = clk;
    assign fifo.rsp_rdy = 1'b1;

    assign r_data_offset = reading_addr[OFSMSB:2];
    assign chosen_r_data = (r_data_offset == 2'b00) ? r1 :
                           (r_data_offset == 2'b01) ? r2 :
                           (r_data_offset == 2'b10) ? r3 : r4;

    (* ram_style = "block" *)reg [PMTSIZE-1:0] bram_for_pmt [0:4095];
    (* ram_style = "block" *)reg [511:0] bram_for_cache [0:4095];

    initial begin
        $readmemh("pmt_ram.mem", bram_for_pmt, 0, 4095);
    end


    enum logic [3:0] {
        IDLE,
        READING,
        WRITING,
        WAIT_R_DDR2,
        WAIT_W_DDR2,
        R_REQ_R_1,
        R_REQ_R_2,
        R_REQ_R_3,
        W_REQ_R_1,
        W_REQ_R_2,
        W_REQ_R_3,
        WAIT_BRAM
    } state = IDLE;

    enum logic [4:0] {
        RSP_IDLE,
        RSP_1,
        RSP_2,
        RSP_3
    } rsp_state = RSP_IDLE;

    enum logic [4:0] {
        WB_IDLE,
        WB_1,
        WB_2,
        WB_3
    } wb_state = WB_IDLE;

    always_ff @ (posedge clk) begin
        doutb_p <= bram_for_pmt[addr[IDXMSB:IDXLSB]];

        doutb_c <= bram_for_cache[addr[IDXMSB:IDXLSB]];

        if(wea_p==1'b1)begin
            bram_for_pmt[addra_p] <= dina_p;
        end
        if(wea_c==1'b1)begin
            bram_for_cache[addra_c] <= dina_c;
        end

    end


    always_ff @ (posedge clk) begin
        if (state == IDLE) begin
            r_data_valid <= 1'b0;
            hit <= 2'b0;
            dirty <= 1'b0;
            done <= 1'b0;
            req_skip <= 1'b0;
            r_stage <= 1'b0;
            if (en==1'b1) begin
                addra_c <= addr[IDXMSB:IDXLSB];
                addra_p <= addr[IDXMSB:IDXLSB];
                wea_c <= 1'b0;
                wea_p <= 1'b0;
                index <= addr[IDXMSB:IDXLSB];
                if(wr == 1'b0) begin //read operation
                    state <= READING;
                    reading_addr <= addr;
                end else begin //write operation
                    state <= WRITING;
                    writing_addr <= addr;
                    writing_data <= w_data;
                end
                idle <=1'b0;
            end else begin
                idle <= 1'b1;
                wea_c <= 1'b0;
                wea_p <= 1'b0;
            end
        end else if (state == READING) begin
            if(doutb_p[TAGSIZE-1:0]==reading_addr[TAGMSB:TAGLSB]) begin
                hit <= 2'b01;//hit
                case(reading_addr[OFSMSB:OFSLSB])
                4'b0000:r_data_reg <= doutb_c[32*1-1:0];
                4'b0001:r_data_reg <= doutb_c[32*2-1:32*1];
                4'b0010:r_data_reg <= doutb_c[32*3-1:32*2];
                4'b0011:r_data_reg <= doutb_c[32*4-1:32*3];
                4'b0100:r_data_reg <= doutb_c[32*5-1:32*4];
                4'b0101:r_data_reg <= doutb_c[32*6-1:32*5];
                4'b0110:r_data_reg <= doutb_c[32*7-1:32*6];
                4'b0111:r_data_reg <= doutb_c[32*8-1:32*7];
                4'b1000:r_data_reg <= doutb_c[32*9-1:32*8];
                4'b1001:r_data_reg <= doutb_c[32*10-1:32*9];
                4'b1010:r_data_reg <= doutb_c[32*11-1:32*10];
                4'b1011:r_data_reg <= doutb_c[32*12-1:32*11];
                4'b1100:r_data_reg <= doutb_c[32*13-1:32*12];
                4'b1101:r_data_reg <= doutb_c[32*14-1:32*13];
                4'b1110:r_data_reg <= doutb_c[32*15-1:32*14];
                4'b1111:r_data_reg <= doutb_c[32*16-1:32*15];
                endcase
                //r_data_valid <= 1'b1;
                r_stage <= 1'b1;
                wea_p <= 1'b1;
                addra_p <= reading_addr[IDXMSB:IDXLSB];
                dina_p <= {3'b0,doutb_p[VD11BIT:DIRTYBIT], doutb_p[TAGSIZE-1:0]};//VD1:kept VD0:kept V:1(kept) DIRTY:kept
                state <= WAIT_BRAM;
                //idle_1 <= 1'b1;
            end
            else begin //read-miss and access to DDR2
                hit <= 2'b10;//miss
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, reading_addr[TAGMSB:IDXLSB],5'b00000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= R_REQ_R_1;
                //rewrite pmt tag
                wea_p <= 1'b1;
                addra_p <= reading_addr[IDXMSB:IDXLSB];
                dina_p <= {3'b0,doutb_p[VD11BIT:VALIDBIT], 1'b0,reading_addr[TAGMSB:TAGLSB]};//VD1:kept VD0:kept V:1(kept) DIRTY:0
                //check dirty
                if (doutb_p[TAGSIZE]==1'b1) begin
                    dirty <= 1'b1;
                    done <= 1'b0;
                    dirty_tag <= doutb_p[TAGSIZE-1:0];
                    wb_data <= doutb_c;
                end
            end
        end else if(state == R_REQ_R_1) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, reading_addr[TAGMSB:IDXLSB],5'b01000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= R_REQ_R_2;
        end else if(state == R_REQ_R_2) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, reading_addr[TAGMSB:IDXLSB],5'b10000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= R_REQ_R_3;
        end else if(state == R_REQ_R_3) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, reading_addr[TAGMSB:IDXLSB],5'b11000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= WAIT_R_DDR2;      
        end else if (state == WAIT_R_DDR2) begin
            //write back
            if(dirty == 1'b1 && done == 1'b0 && wb_state == WB_IDLE) begin
                wb_state <= WB_1;
                done <= 1'b1;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b00000};
                fifo.req.data <= wb_data[128*1-1:0];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_1) begin
                wb_state <= WB_2;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b01000};
                fifo.req.data <= wb_data[128*2-1:128*1];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_2) begin
                wb_state <= WB_3;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b10000};
                fifo.req.data <= wb_data[128*3-1:128*2];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_3) begin
                wb_state <= WB_IDLE;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b11000};
                fifo.req.data <= wb_data[128*4-1:128*3];
                fifo.req_en <= 1'b1;
            end else begin
                fifo.req_en <= 1'b0;
            end
            if (rsp_4_ready == 1'b1) begin
                case(reading_addr[1:OFSLSB])
                2'b00:r_data_reg <= chosen_r_data[32*1-1:0];
                2'b01:r_data_reg <= chosen_r_data[32*2-1:32*1];
                2'b10:r_data_reg <= chosen_r_data[32*3-1:32*2];
                2'b11:r_data_reg <= chosen_r_data[32*4-1:32*3];
                endcase
                //rewrite cache
                wea_c <= 1'b1;
                addra_c <= reading_addr[IDXMSB:IDXLSB];
                dina_c <= {r4,r3,r2,r1};

                //r_data_valid <= 1'b1;
                r_stage <= 1'b1;
                if(dirty == 1'b0 || (wb_state == WB_IDLE && done == 1'b1))begin
                    state <= WAIT_BRAM;
                    //idle_1 <= 1'b1;
                end
            end
        end else if (state == WRITING) begin
            //no-valid-data isn't required to be written back
            //hit or no-valid on ddr2
            if (doutb_p[TAGSIZE-1:0]==writing_addr[TAGMSB:TAGLSB] || doutb_p[VALIDBIT]==1'b0) begin 
                hit <= 2'b01;//hit
                addra_c <= writing_addr[IDXMSB:IDXLSB];
                wea_c <= 1'b1;
                case(writing_addr[OFSMSB:OFSLSB])//overwrite cache
                4'b0000:dina_c <= {doutb_c[LINESIZE*32-1:32*1], writing_data};
                4'b0001:dina_c <= {doutb_c[LINESIZE*32-1:32*2], writing_data, doutb_c[32*1-1:0]};
                4'b0010:dina_c <= {doutb_c[LINESIZE*32-1:32*3], writing_data, doutb_c[32*2-1:0]};
                4'b0011:dina_c <= {doutb_c[LINESIZE*32-1:32*4], writing_data, doutb_c[32*3-1:0]};
                4'b0100:dina_c <= {doutb_c[LINESIZE*32-1:32*5], writing_data, doutb_c[32*4-1:0]};
                4'b0101:dina_c <= {doutb_c[LINESIZE*32-1:32*6], writing_data, doutb_c[32*5-1:0]};
                4'b0110:dina_c <= {doutb_c[LINESIZE*32-1:32*7], writing_data, doutb_c[32*6-1:0]};
                4'b0111:dina_c <= {doutb_c[LINESIZE*32-1:32*8], writing_data, doutb_c[32*7-1:0]};
                4'b1000:dina_c <= {doutb_c[LINESIZE*32-1:32*9], writing_data, doutb_c[32*8-1:0]};
                4'b1001:dina_c <= {doutb_c[LINESIZE*32-1:32*10], writing_data, doutb_c[32*9-1:0]};
                4'b1010:dina_c <= {doutb_c[LINESIZE*32-1:32*11], writing_data, doutb_c[32*10-1:0]};
                4'b1011:dina_c <= {doutb_c[LINESIZE*32-1:32*12], writing_data, doutb_c[32*11-1:0]};
                4'b1100:dina_c <= {doutb_c[LINESIZE*32-1:32*13], writing_data, doutb_c[32*12-1:0]};
                4'b1101:dina_c <= {doutb_c[LINESIZE*32-1:32*14], writing_data, doutb_c[32*13-1:0]};
                4'b1110:dina_c <= {doutb_c[LINESIZE*32-1:32*15], writing_data, doutb_c[32*14-1:0]};
                4'b1111:dina_c <= {writing_data, doutb_c[32*15-1:0]};
                endcase

                //rewrite pmt tag
                wea_p <= 1'b1;
                addra_p <= writing_addr[IDXMSB:IDXLSB];
                case(writing_addr[TAGLSB+1:TAGLSB])
                2'b00:dina_p <= {3'b0,doutb_p[VD11BIT:VD01BIT], 1'b1, 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:kept VD0:1 V:1 DIRTY:1
                2'b01:dina_p <= {3'b0,doutb_p[VD11BIT:VD10BIT], 1'b1, doutb_p[VD00BIT], 1'b1, 1'b1 ,writing_addr[TAGMSB:TAGLSB]};//VD1:1 VD0:kept V:1 DIRTY:1
                2'b10:dina_p <= {3'b0,doutb_p[VD11BIT], 1'b1, doutb_p[VD01BIT:VD00BIT], 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:kept VD0:1 V:1 DIRTY:1
                2'b11:dina_p <= {3'b0,1'b1, doutb_p[VD10BIT:VD00BIT],1'b1, 1'b1,writing_addr[TAGMSB:TAGLSB]};//VD1:1 VD0:kept V:1 DIRTY:1
                endcase
                state <= WAIT_BRAM;
                //idle_1 <= 1'b1;

            end else begin //overwrite DDR2
                hit <= 2'b10;//miss

                if(writing_addr[TAGLSB+1:TAGLSB]==2'b00)begin//tag0
                    if(doutb_p[VD00BIT]==1'b1)begin//On DDR2, there is valid data
                        //get data around w_data from DDR2
                        fifo.req.cmd <= 1'b1;//read
                        fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b00000};
                        fifo.req.data <= 'b0;
                        fifo.req_en <= 1'b1;

                        state <= W_REQ_R_1;
                    end else begin//On DDR2, there is no valid data
                        if(doutb_p[DIRTYBIT]==1'b1)begin//dirty
                            state <= WAIT_W_DDR2;//write back
                            req_skip <= 1'b1;//but, req can be skipped
                        end else begin
                            state <= WAIT_BRAM;
                        end
                    end
                    //rewrite pmt tag
                    wea_p <= 1'b1;
                    dina_p <= {3'b0,doutb_p[VD11BIT:VD01BIT], 1'b1, 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:kept VD0:1 V:1 DIRTY:1
                end else if(writing_addr[TAGLSB+1:TAGLSB]==2'b01) begin//tag1
                    if(doutb_p[VD01BIT]==1'b1)begin//On DDR2, there is valid data
                    //get data around w_data from DDR2
                        fifo.req.cmd <= 1'b1;//read
                        fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b00000};
                        fifo.req.data <= 'b0;
                        fifo.req_en <= 1'b1;

                        state <= W_REQ_R_1;
                    end else begin//On DDR2, there is no valid data
                        if(doutb_p[DIRTYBIT]==1'b1)begin//dirty
                            state <= WAIT_W_DDR2;//write back
                            req_skip <= 1'b1;//but, req can be skipped
                        end else begin
                            state <= WAIT_BRAM;
                        end
                    end
                    //rewrite pmt tag
                    wea_p <= 1'b1;
                    dina_p <= {3'b0,doutb_p[VD11BIT:VD10BIT],1'b1, doutb_p[VD00BIT], 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:1 VD0:kept V:1 DIRTY:1
                end else if(writing_addr[TAGLSB+1:TAGLSB]==2'b10) begin//tag1
                    if(doutb_p[VD10BIT]==1'b1)begin//On DDR2, there is valid data
                    //get data around w_data from DDR2
                        fifo.req.cmd <= 1'b1;//read
                        fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b00000};
                        fifo.req.data <= 'b0;
                        fifo.req_en <= 1'b1;

                        state <= W_REQ_R_1;
                    end else begin//On DDR2, there is no valid data
                        if(doutb_p[DIRTYBIT]==1'b1)begin//dirty
                            state <= WAIT_W_DDR2;//write back
                            req_skip <= 1'b1;//but, req can be skipped
                        end else begin
                            state <= WAIT_BRAM;
                        end
                    end
                    //rewrite pmt tag
                    wea_p <= 1'b1;
                    dina_p <= {3'b0,doutb_p[VD11BIT],1'b1, doutb_p[VD01BIT:VD00BIT], 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:1 VD0:kept V:1 DIRTY:1
                end else begin//tag11
                    if(doutb_p[VD11BIT]==1'b1)begin//On DDR2, there is valid data
                    //get data around w_data from DDR2
                        fifo.req.cmd <= 1'b1;//read
                        fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b00000};
                        fifo.req.data <= 'b0;
                        fifo.req_en <= 1'b1;

                        state <= W_REQ_R_1;
                    end else begin//On DDR2, there is no valid data
                        if(doutb_p[DIRTYBIT]==1'b1)begin//dirty
                            state <= WAIT_W_DDR2;//write back
                            req_skip <= 1'b1;//but, req can be skipped
                        end else begin
                            state <= WAIT_BRAM;
                        end
                    end
                    //rewrite pmt tag
                    wea_p <= 1'b1;
                    dina_p <= {3'b0,1'b1, doutb_p[VD10BIT:VD00BIT], 1'b1, 1'b1, writing_addr[TAGMSB:TAGLSB]};//VD1:1 VD0:kept V:1 DIRTY:1
                end
                //rewrite pmt
                addra_p <= writing_addr[IDXMSB:IDXLSB];
                //check dirty
                if (doutb_p[DIRTYBIT]==1'b1) begin
                    dirty <= 1'b1;
                    done <= 1'b0;
                    dirty_tag <= doutb_p[TAGSIZE-1:0];
                    wb_data <= doutb_c;
                end
            end
        end else if(state == W_REQ_R_1) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b01000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= W_REQ_R_2;
        end else if(state == W_REQ_R_2) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b10000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= W_REQ_R_3;
        end else if(state == W_REQ_R_3) begin
                fifo.req.cmd <= 1'b1;//read
                fifo.req.addr <= {8'b0, writing_addr[TAGMSB:IDXLSB],5'b11000};
                fifo.req.data <= '0;
                fifo.req_en <= 1'b1;
                state <= WAIT_W_DDR2;      
        end else if(state == WAIT_W_DDR2) begin
            if(dirty == 1'b1 && done == 1'b0 && wb_state == WB_IDLE) begin
                wb_state <= WB_1;
                done <= 1'b1;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b00000};
                fifo.req.data <= wb_data[128*1-1:0];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_1) begin
                wb_state <= WB_2;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b01000};
                fifo.req.data <= wb_data[128*2-1:128*1];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_2) begin
                wb_state <= WB_3;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b10000};
                fifo.req.data <= wb_data[128*3-1:128*2];
                fifo.req_en <= 1'b1;
            end else if(wb_state == WB_3) begin
                wb_state <= WB_IDLE;
                fifo.req.cmd <= 1'b0;//write
                fifo.req.addr <= {8'b0,dirty_tag,index,5'b11000};
                fifo.req.data <= wb_data[128*4-1:128*3];
                fifo.req_en <= 1'b1;
            end else begin
                fifo.req_en <= 1'b0;
            end
            if (rsp_4_ready == 1'b1 || req_skip == 1'b1) begin
                wea_c <= 1'b1;

                case(writing_addr[OFSMSB:OFSLSB])//overwrite cache
                4'b0000:dina_c <= {r4, r3, r2, r1[32*4-1:32*1], writing_data};
                4'b0001:dina_c <= {r4, r3, r2, r1[32*4-1:32*2], writing_data, r1[32*1-1:0]};
                4'b0010:dina_c <= {r4, r3, r2, r1[32*4-1:32*3], writing_data, r1[32*2-1:0]};
                4'b0011:dina_c <= {r4, r3, r2, writing_data,r1[32*3-1:0]};
                4'b0100:dina_c <= {r4, r3, r2[32*4-1:32*1], writing_data, r1};
                4'b0101:dina_c <= {r4, r3, r2[32*4-1:32*2], writing_data, r2[32*1-1:0], r1};
                4'b0110:dina_c <= {r4, r3, r2[32*4-1:32*3], writing_data, r2[32*2-1:0], r1};
                4'b0111:dina_c <= {r4, r3, writing_data, r2[32*3-1:0], r1};
                4'b1000:dina_c <= {r4, r3[32*4-1:32*1], writing_data, r2, r1};
                4'b1001:dina_c <= {r4, r3[32*4-1:32*2], writing_data, r3[32*1-1:0], r2, r1};
                4'b1010:dina_c <= {r4, r3[32*4-1:32*3], writing_data, r3[32*2-1:0], r2, r1};
                4'b1011:dina_c <= {r4, writing_data, r3[32*3-1:0], r2, r1};
                4'b1100:dina_c <= {r4[32*4-1:32*1], writing_data, r3, r2, r1};
                4'b1101:dina_c <= {r4[32*4-1:32*2], writing_data, r4[32*1-1:0], r3, r2, r1};
                4'b1110:dina_c <= {r4[32*4-1:32*3], writing_data, r4[32*2-1:0], r3, r2, r1};
                4'b1111:dina_c <= {writing_data, r4[32*3-1:0], r3, r2, r1};
                endcase
                addra_c <= writing_addr[IDXMSB:IDXLSB];
                if(dirty == 1'b0 || (wb_state == WB_IDLE && done == 1'b1))begin
                    state <= WAIT_BRAM;
                    //idle_1 <= 1'b1;
                end
            end
        end else if(state == WAIT_BRAM) begin
                state <= IDLE;
                idle <= 1'b1;
                if(r_stage == 1'b1)begin
                    r_data_valid <= 1'b1;
                    r_data <= r_data_reg;
                end
        end 
    end

    always_ff @ (posedge clk) begin
        if(rsp_state==RSP_IDLE)begin
            rsp_4_ready <= 1'b0;
            if(fifo.rsp_en == 1'b1) begin
                rsp_state <= RSP_1;
                r1 <= fifo.rsp.data;
            end
        end else if(rsp_state == RSP_1) begin
            if(fifo.rsp_en == 1'b1) begin
                rsp_state <= RSP_2;
                r2 <= fifo.rsp.data;
            end
        end else if(rsp_state == RSP_2) begin
            if(fifo.rsp_en == 1'b1) begin
                rsp_state <= RSP_3;
                r3 <= fifo.rsp.data;
            end
        end else if(rsp_state == RSP_3) begin
            if(fifo.rsp_en == 1'b1) begin
                rsp_state <= RSP_IDLE;
                r4 <= fifo.rsp.data;
                rsp_4_ready <= 1'b1;
            end
        end
    end
endmodule
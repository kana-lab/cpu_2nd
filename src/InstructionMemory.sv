module InstructionMemory #(
    INSTR_MEM_SIZE = 32'h8000
) (
    input wire clock,
    input wire reset,

    IInstr.slave request,

    input wire push,
    input wire [31:0] push_data
);
    (* ram_style = "block" *) reg [31:0] bram[INSTR_MEM_SIZE - 1:0];

    reg [15:0] counter;
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
        end else begin
            if (push) begin
                counter <= counter + 16'd1;
                bram[counter] <= push_data;
            end else begin
                request.instr <= bram[request.addr];
            end
        end
    end
endmodule
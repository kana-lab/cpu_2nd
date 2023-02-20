`include "typedefs.svh"

module InstructionMemory #(
    INSTR_MEM_SIZE = 32'h8000
) (
    input wire clock,
    input wire reset,

    IInstr.slave request,

    input wire push,
    input w32 push_data
);
    (* ram_style = "block" *) r32 bram[INSTR_MEM_SIZE - 1:0];

    reg [15:0] counter;
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
        end else begin
            if (push) begin
                counter <= counter + 'd1;
                bram[counter] <= push_data;
            end else begin
                request.instr <= bram[request.addr];
            end
        end
    end
endmodule
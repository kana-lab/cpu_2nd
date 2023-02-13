// instrはreset中に初期化されないので注意
interface IInstr;
    wire [31:0] addr;
    reg [31:0] instr;

    modport master (
        input instr,
        output addr
    );

    modport slave (
        input addr,
        output instr
    );
endinterface
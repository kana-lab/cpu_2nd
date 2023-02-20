`include "../typedefs.svh"

// instrはreset中に初期化されないので注意
interface IInstr;
    w32 addr;
    r32 instr;

    modport master (
        input instr,
        output addr
    );

    modport slave (
        input addr,
        output instr
    );
endinterface
// enはreset中、stall中にONにならないようにすべき
interface IFpu;
    wire en;
    wire [4:0] funct;
    wire [31:0] val1;
    wire [31:0] val2;
    wire [31:0] result;
    wire stall;

    modport master (
        input result, stall,
        output en, funct, val1, val2
    );

    modport slave (
        input en, funct, val1, val2,
        output result, stall
    );
endinterface
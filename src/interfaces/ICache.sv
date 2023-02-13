// enはreset中、stall中にONにならないようにすべき
interface ICache;
    wire en;
    wire we;
    wire [31:0] addr;
    wire [31:0] rd;
    wire [31:0] wd;
    wire stall;

    modport master (
        input rd, stall,
        output en, we, addr, wd
    );

    modport slave (
        input en, we, addr, wd,
        output rd, stall
    );
endinterface
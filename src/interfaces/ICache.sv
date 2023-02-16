// enはreset中、stall中にONにならないようにすべき
interface ICache;
    wire en;
    wire we;
    w32 addr;
    w32 rd;
    w32 wd;
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
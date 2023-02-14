interface IAluInput;
    reg en;
    reg imm;
    reg mov;
    reg [3:0] funct;
    reg [7:0] src1;
    reg [7:0] src2;
    reg [31:0] read1;
    reg [31:0] read2;
    reg [31:0] read_dest;

    modport master (
        output en, imm, mov, funct, src1, src2, read1, read2, read_dest
    );

    modport slave (
        input en, imm, mov, funct, src1, src2, read1, read2, read_dest
    );
endinterface

interface IFpuInput;
    reg en;
    reg [4:0] funct;
    reg [31:0] val1;
    reg [31:0] val2;

    modport master (
        output en, funct, val1, val2
    );

    modport slave (
        input en, funct, val1, val2
    );
endinterface

interface IBuInput;
    reg en;
    reg [2:0] funct;
    reg [31:0] jump_addr;
    reg [31:0] read1;
    reg [31:0] read2;

    modport master (
        output en, funct, offset, read1, read2
    );

    modport slave (
        input en, funct, offset, read1, read2
    );
endinterface

interface IDevice;
    reg en;
    reg wb;
    reg uart;
    reg neg;
    reg [7:0] offset;
    reg [31:0] addr;
    reg [31:0] val;

    modport master (
        output en, wb, uart, neg, imm_ext, addr, val
    );

    modport slave (
        input en, wb, uart, neg, imm_ext, addr, val
    );
endinterface
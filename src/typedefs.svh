`ifndef TYPEDEFS
`define TYPEDEFS

typedef logic [63:0] r64;
typedef logic [31:0] r32;
typedef logic [15:0] r16;
typedef logic [7:0] r8;
typedef logic [63:0] w64;
typedef logic [31:0] w32;
typedef logic [16:0] w16;
typedef logic [7:0] w8;

typedef struct {
    logic en;
    logic miss;
    logic taken;
    w32 current_pc;
    w32 jump_addr;
} BranchResult;

`endif  // TYPEDEFS
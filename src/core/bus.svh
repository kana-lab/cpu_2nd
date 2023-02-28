`ifndef BUS
`define BUS

`include "../typedefs.svh"

interface Message #(
    type message_t = logic [0:0]
);
    logic en;
    logic reject;
    message_t msg;

    modport sender (
        input reject,
        output en, msg
    );

    modport receiver (
        input en, msg,
        output reject
    );

    function send_failed ();
        return this.en & this.rejected;
    endfunction
endinterface

typedef struct {
    w32 instr;
    w16 pc;
    logic approx;
} IFResult;

typedef struct packed {
    logic miss;
    logic taken;
    u16 current_pc;
    u16 jump_addr;
} BranchResult;

typedef struct {
    w8 dest_logic;
    w64 dest_phys;
    w32 data;
} CompleteInfo;

typedef struct {
    w8 dest_logic;
    w32 data;
} CommitInfo;

typedef struct {
    logic valid;
    union {
        u32 data;
        u64 tag;
    } content;
} Source;

typedef struct {
    u8 commit_id;
    logic [1:0] aux_op;
    logic [2:0] funct3;
    u8 dest_logic;
    u64 dest_phys;
    Source src1;
    Source src2;
} AluInstr;

typedef struct {
    u8 commit_id;
    logic [4:0] funct5;
    u8 dest_logic;
    u64 dest_phys;
    Source src1;
    Source src2;
} FpuInstr;

typedef struct {
    u8 commit_id;
    logic jr;  // is jump register instr?
    logic approx;
    logic [2:0] funct3;
    u16 new_pc;
    Source src1;
    Source src2;
} BranchInstr;

typedef struct {
    u8 commit_id;
    logic ls;  // load/store
    logic pm;  // plus/minus of offset
    Source addr;
    u8 offset;
    union {
        Source store;
        struct {
            u8 dest_logic;
            u64 dest_phys;
        } load;
    } r;
} MemoryInstr;

typedef struct {
    u8 commit_id;
    logic sr;  // send/recv;
    union {
        Source send;
        struct {
            u8 dest_logic;
            u64 dest_phys;
        } recv;
    } operand;
} UartInstr;

typedef struct {
    logic kind;  // 0: wb, 1: branch
    logic notify_only;  // usend, sw/swnの場合notifyのみになる
    logic fin;  // fin == 1であってもevent == 'b00になるまで保持すべき

    union {
        struct {
            logic [1:0] notify;  // notify[0]: uart, notify[1]: sw
            w8 dest_logic;
            w32 data;
        } wb;

        BranchResult branch;
    } content;
} CommitEntry;

// interface IPushCommit;
//     wire en;
//     w8 commit_id;
//     CommitEntry commit_entry;

//     modport master (
//         input commit_id,
//         output en, commit_entry
//     );

//     modport slave (
//         input en, commit_entry,
//         output commit_id
//     );
// endinterface

typedef struct packed {
    u8 commit_id;
    logic kind;  // 0: wb, 1: branch
    union packed {
        struct packed {
            u8 dest_phys;
            u32 data;
        } wb;
        struct packed {
            logic miss;
            logic taken;
            u16 new_pc;
            logic [21:0] buf_;
        } branch;
    } content;
} Result;

`endif  // BUS
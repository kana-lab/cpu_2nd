// typedef struct {
//     wire en;
//     w8 dest_logic;
//     w64 dest_phys;
//     w32 data;
// } CompleteInfo;

// interface CompleteInfo;
//     wire en;
//     w8 dest_logic;
//     w64 dest_phys;
//     w32 data;
// endinterface

// typedef struct {
//     wire en;
//     w8 dest_logic;
//     w32 data;
// } CommitInfo;

// interface CommitInfo;
//     wire en;
//     w8 dest_logic;
//     w32 data;
// endinterface

typedef struct {
    bool en;
    bool miss;
    bool taken;
    u32 current_pc;
    u32 jump_addr;
} BranchResult;

// interface BranchResult;
//     wire en;
//     wire miss;
//     wire taken;
//     w32 current_pc;
//     w32 jump_addr;
// endinterface
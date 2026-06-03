package tricycle_pkg;

/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

// Utility functions for parameters
function int clamp0 (int v);
    if (v < 0) return 0;
    else return v;
endfunction

// RISC-V Definitions

typedef logic [31:0] l32;
typedef l32 [1:0] l64;

localparam l32 RESET_PC = 'h80000000;

typedef logic [4:0] rv_reg_id_t;

// Decoding defaults to R-Type
typedef struct packed {
    logic [6:0] funct7;     // [31:25]
    logic [4:0] rs2;        // [24:20]
    logic [4:0] rs1;        // [19:15]
    logic [2:0] funct3;     // [14:12]
    logic [4:0] rd;         // [11:07]
    logic [6:0] opcode;     // [06:00]
} rv_instr_t /*verilator public*/;

// Nop operation add x0 x0, 0 (0x00000033)
localparam rv_instr_t RV_NOP = 'h33;

// Imediate generation functions
function automatic logic[31:0] decode_i_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:11] = '{default: instr[31]};
    imm[10:0] = instr[30:20];
    return imm;
endfunction

function automatic logic[31:0] decode_s_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:11] = '{default: instr[31]};
    imm[10:5] = instr[30:25];
    imm[4:0] = instr[11:7];
    return imm;
endfunction

function automatic logic[31:0] decode_b_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:12] = '{default: instr[31]};
    imm[11] = instr[7];
    imm[10:5] = instr[30:25];
    imm[4:1] = instr[11:8];
    imm[0] = 0;
    return imm;
endfunction

function automatic logic[31:0] decode_u_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:12] = instr[31:12];
    imm[11:0] = '{default: 0};
    return imm;
endfunction

function automatic logic[31:0] decode_j_imm(input logic[31:0] instr);
    logic[31:0] imm;
    imm[31:20] = '{default: instr[31]};
    imm[19:12] = instr[19:12];
    imm[11] = instr[20];
    imm[10:1] = instr[30:21];
    imm[0] = 0;
    return imm;
endfunction

typedef enum logic [6:0] {
    OPCODE_LUI           = 7'b0110111,
    OPCODE_AUIPC         = 7'b0010111,
    OPCODE_JAL           = 7'b1101111,
    OPCODE_JALR          = 7'b1100111,
    OPCODE_BRANCH        = 7'b1100011,
    OPCODE_LOAD          = 7'b0000011,
    OPCODE_STORE         = 7'b0100011,
    OPCODE_INTEGER_IMM   = 7'b0010011,
    OPCODE_INTEGER_REG   = 7'b0110011
} valid_opcodes_t /*verilator public*/;

typedef enum logic [2:0] {
    IMM_0,
    IMM_I,
    IMM_S,
    IMM_B,
    IMM_U,
    IMM_J
} imm_t /*verilator public*/;

typedef enum logic [3:0] {
    ALU_OP_ADD  = 4'b0000,
    ALU_OP_SLL  = 4'b0001, // SLL shift left logical
    ALU_OP_SLT  = 4'b0010, // SLT set less than
    ALU_OP_SLTU = 4'b0011,
    ALU_OP_XOR  = 4'b0100,
    ALU_OP_SRL  = 4'b0101, // SRL shift right logical
    ALU_OP_OR   = 4'b0110,
    ALU_OP_AND  = 4'b0111,
    ALU_OP_SUB  = 4'b1000,
    ALU_OP_SRA  = 4'b1101 // SRA shift right arithmetic
} int_alu_op_t /*verilator public*/;

typedef enum logic[1:0] {
    ALU_IN_PC_IMM,
    ALU_IN_R1_IMM,
    ALU_IN_R1_R2
} int_alu_input_t /*verilator public*/;

// Mul operations
typedef enum logic [1:0] {
    MUL_OP_MUL    = 2'b00,
    MUL_OP_MULH   = 2'b01,
    MUL_OP_MULHSU = 2'b10,
    MUL_OP_MULHU  = 2'b11
} mul_op_t /*verilator public*/;

// Div operations
typedef enum logic [1:0] {
    DIV_OP_DIV  = 2'b00,
    DIV_OP_DIVU = 2'b01,
    DIV_OP_REM  = 2'b10,
    DIV_OP_REMU = 2'b11
} div_op_t /*verilator public*/;

typedef enum logic [3:0] {
    OP_BEQ  = 4'b0000,
    OP_BNE  = 4'b0001,
    OP_BLT  = 4'b0100,
    OP_BGE  = 4'b0101,
    OP_BLTU = 4'b0110,
    OP_BGEU = 4'b0111,
    OP_J    = 4'b1000,
    OP_NOP  = 4'b1111
} branch_op_t /*verilator public*/;

typedef enum logic [3:0] {
    MEM_LB   = 4'b0000,
    MEM_LH   = 4'b0001,
    MEM_LW   = 4'b0010,
    MEM_LBU  = 4'b0100,
    MEM_LHU  = 4'b0101,
    MEM_SB   = 4'b1000,
    MEM_SH   = 4'b1001,
    MEM_SW   = 4'b1010,
    MEM_NOP  = 4'b1111
} mem_op_t /*verilator public*/;

typedef enum logic [2:0] {
    // Standard outputs
    WB_IMM,
    WB_ALU,
    WB_PC4,
    WB_LOAD,
    WB_MUL,
    WB_DIV
} wb_result_t /*verilator public*/;

typedef struct packed {
    imm_t imm;
    branch_op_t branch_op;
    int_alu_op_t int_alu_op;
    int_alu_input_t int_alu_input;
    mem_op_t mem_op;
    logic is_store;
    wb_result_t wb_result_src;
    logic rf_write;
} control_t /*verilator public*/;

// Used for NOP generation
function automatic control_t create_nop_ctrl();
    control_t instr;
    instr.imm = IMM_0;
    instr.branch_op = OP_NOP;
    instr.int_alu_op = ALU_OP_ADD;
    instr.int_alu_input = ALU_IN_R1_R2;
    instr.mem_op = MEM_NOP;
    instr.is_store = 0;
    instr.wb_result_src = WB_ALU;
    instr.rf_write = 0;

    return instr;
endfunction

typedef enum logic [1:0] {
    NO_FLUSH,
    FLUSH_BRANCH,
    FLUSH_TRAP
} flush_type_t;

typedef struct packed {
    flush_type_t op;
    l32 from;
    l32 to;
} flush_bus_t /*verilator public*/;

typedef struct packed {
    logic write_enable;
    rv_reg_id_t id;
    l32 data;
} rf_write_request_t /*verilator public*/;

typedef struct packed {
    l32 addr;
    l32 data;
    mem_op_t op;
} mem_request_t /*verilator public*/;

// Stage buffers

typedef struct packed {
    logic valid;
} fetch_dec_buff_t;

typedef struct packed {
    control_t control;
    rv_instr_t instr;
    l32 pc;
    l32 pc4;
    l32 imm;
    l32 [1:0] reg_data;
} dec_exec_buff_t;

endpackage

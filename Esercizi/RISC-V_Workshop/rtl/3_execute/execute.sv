/* verilator lint_off UNUSEDSIGNAL */

module execute 
import tricycle_pkg::*;
(
    input logic clk, resetn, enable,

    // Pipeline D-E
    input dec_exec_buff_t dec_data,
    output logic exec_ready,

    // Data Mem I/O
    output mem_request_t data_req,
    input logic data_req_ack,
    input l32 mem_data,
    input logic data_req_done,

    // Register File
    output rf_write_request_t rf_req_reg,

    // Flush
    output flush_bus_t flush_bus
);

typedef enum logic [2:0] {IDLE, MEM_BEGIN, MEM_END} state_t;
state_t state, next_state;


l32 [1:0] reg_data;
rv_reg_id_t [1:0] rf_read_ids;

always_comb begin 
    reg_data[0] = dec_data.reg_data[0];
    reg_data[1] = dec_data.reg_data[1];
end

l32 alu_op1, alu_op2, int_alu_out;
always_comb begin 
    case (dec_data.control.int_alu_input)
        ALU_IN_PC_IMM: begin 
            alu_op1 = dec_data.pc;
            alu_op2 = dec_data.imm;
        end
        ALU_IN_R1_IMM: begin 
            alu_op1 = reg_data[0];
            alu_op2 = dec_data.imm;
        end
        default: begin 
            alu_op1 = reg_data[0];
            alu_op2 = reg_data[1];
        end
    endcase
end
int_alu int_alu (
    .op1(alu_op1), .op2(alu_op2), .result(int_alu_out),
    .opsel(dec_data.control.int_alu_op)
);

l32 int_mul_out;
int_mul int_mul (
    .op1(reg_data[0]), .op2(reg_data[1]),
    .opsel(mul_op_t'(dec_data.instr.funct3[1:0])),
    .result(int_mul_out)
);

l32 int_div_out;
int_div int_div (
    .op1(reg_data[0]), .op2(reg_data[1]),
    .opsel(div_op_t'(dec_data.instr.funct3[1:0])),
    .result(int_div_out)
);

logic do_branch;
branch branch (
    .op1(reg_data[0]), .op2(reg_data[1]),
    .branch_op(dec_data.control.branch_op),
    .do_branch(do_branch)
);

l32 request_addr, request_data, fixed_load;
logic store_mem_req;
load_fix load_fix (
    .op(dec_data.control.mem_op), 
    .addr(request_addr), .raw_load(mem_data),
    .fixed_load(fixed_load)
);


// Memory request
always_comb begin 
    // These are just comb paths
    data_req.addr = request_addr;
    data_req.data = request_data;
    data_req.op = MEM_NOP;

    // Send the data request
    if (state == MEM_BEGIN) begin
        data_req.op = dec_data.control.mem_op;
    end
end


rf_write_request_t current_rf_req;
always_comb begin
    // Register file, output MUX
    current_rf_req.id = dec_data.instr.rd;
    case (dec_data.control.wb_result_src)
        WB_IMM: current_rf_req.data = dec_data.imm;
        WB_PC4: current_rf_req.data = dec_data.pc4;
        WB_LOAD: current_rf_req.data = fixed_load; 
        WB_MUL: current_rf_req.data = int_mul_out;
        WB_DIV: current_rf_req.data = int_div_out;
        default: current_rf_req.data = int_alu_out;
    endcase
end

always_comb begin
    next_state = state;

    // Important signals controlled by state machine
    flush_bus.op = NO_FLUSH;
    flush_bus.from = dec_data.pc;
    flush_bus.to = int_alu_out;

    current_rf_req.write_enable = 0;
    exec_ready = 0;
    store_mem_req = 0;

    case (state)
        IDLE: begin
            if (enable) begin
                // Memory instructions
                if (dec_data.control.mem_op != MEM_NOP) begin 
                    store_mem_req = 1;
                    next_state = MEM_BEGIN;
                end
                // Branch instruction
                else if (do_branch) begin 
                    exec_ready = 1;
                    flush_bus.op = FLUSH_BRANCH;
                    current_rf_req.write_enable = dec_data.control.rf_write;
                end
                // Other 1 cycle instructions
                else begin 
                    exec_ready = 1;
                    current_rf_req.write_enable = dec_data.control.rf_write;
                end
            end
        end

        MEM_BEGIN: begin
            if (data_req_ack) begin 
                // Wait for the response from memory
                next_state = MEM_END;
            end
        end
        MEM_END: begin 
            if (data_req_done) begin 
                current_rf_req.write_enable = dec_data.control.rf_write;
                exec_ready = 1;
                next_state = IDLE;
            end
        end

        default: begin end
    endcase
end

always_comb begin 
    rf_req_reg = current_rf_req;
end

always_ff @(posedge clk) begin
    if (!resetn) begin 
        state <= IDLE;
    end
    else begin
        // State machine
        state <= next_state;
        
        if (store_mem_req) begin
            request_addr <= int_alu_out;
            request_data <= reg_data[1];
        end

    end
end

endmodule

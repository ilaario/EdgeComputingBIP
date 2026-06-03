/* verilator lint_off UNUSEDSIGNAL */

module decode 
import tricycle_pkg::*;
(
    input logic clk, resetn, enable,

    // Instr bus response
    input rv_instr_t instr,
    input logic instr_req_done,

    // Register file
    output rv_reg_id_t [1:0] rf_read_ids,
    input l32 [1:0] rf_data,
    
    // Data for Bypass and Hazzards
    input rf_write_request_t rf_write_req,

    // Pipeline F-D
    input fetch_dec_buff_t fetch_dec_buff,
    output logic dec_ready,

    // Pipeline D-E
    input logic exec_ready,
    output dec_exec_buff_t dec_exec_buff,

    input flush_bus_t flush_bus
);

parameter int IFIFO_SIZE = 4;
parameter int IFIFO_COUNT_SIZE = $clog2(IFIFO_SIZE);

// Replicate pc logic
l32 pc, pc4;
assign pc4 = pc + 4;

logic fifo_flush;
logic [IFIFO_COUNT_SIZE: 0] instr_fifo_count, instr_fifo_free;
logic instr_fifo_get, instr_fifo_add;
l32 instr_fifo_data;

basic_fifo # (
    .SIZE(IFIFO_SIZE)
) 
instr_fifo (
    .clk(clk), .resetn(resetn), .flush(fifo_flush),
    .nfree(instr_fifo_free), .count(instr_fifo_count),
    .add(instr_fifo_add), .i_data(instr),
    .get(instr_fifo_get), .o_data(instr_fifo_data)
);

// There is valid data coming from the instruction bus
logic instr_handshake;
assign instr_handshake = (fetch_dec_buff.valid && instr_req_done);

// At least 2 instruction free are required to be ready
assign dec_ready = (instr_fifo_free > 1);

logic instr_in_fifo;
assign instr_in_fifo = (instr_fifo_count > 0);

rv_instr_t instr_to_decode;
control_t decoded_ctrl;

always_comb begin 
    // If there are pending instructions use those
    if (instr_in_fifo) instr_to_decode = instr_fifo_data;
    // Use the one coming from the bus
    else instr_to_decode = instr;
end

decoder decoder(
    .instr(instr_to_decode),
    .control(decoded_ctrl)
);

always_comb begin
    // Read rf
    rf_read_ids[0] = instr_to_decode.rs1;
    rf_read_ids[1] = instr_to_decode.rs2;
end

// Bypass last write
l32 [1:0] bypass_reg_data;
always_comb begin 
    for (int i = 0; i < 2; i += 1) begin 
        if (rf_write_req.write_enable && rf_read_ids[i] == rf_write_req.id) begin
            bypass_reg_data[i] = rf_write_req.data;
        end
        else bypass_reg_data[i] = rf_data[i];
    end
end

dec_exec_buff_t ibuff;
always_comb begin 
    // Prepare decoded structure
    ibuff.control = decoded_ctrl;
    ibuff.instr = instr_to_decode;
    ibuff.pc = pc;
    ibuff.pc4 = pc4;
    ibuff.reg_data = bypass_reg_data;

    // Generate immediate
    case (decoded_ctrl.imm)
        IMM_I: ibuff.imm = decode_i_imm(instr_to_decode);
        IMM_S: ibuff.imm = decode_s_imm(instr_to_decode);
        IMM_B: ibuff.imm = decode_b_imm(instr_to_decode);
        IMM_U: ibuff.imm = decode_u_imm(instr_to_decode);
        IMM_J: ibuff.imm = decode_j_imm(instr_to_decode);
        default: ibuff.imm = 0;
    endcase
end

// Control the instruction buffer
logic dec_valid, dec_exec_handshake;

always_comb begin 
    instr_fifo_add = 0;
    instr_fifo_get = 0;
    fifo_flush = (flush_bus.op != NO_FLUSH);

    // There was an instruction to decode
    dec_valid = (instr_in_fifo || instr_handshake);
    // Check if the instruction can be added to D-E buff
    dec_exec_handshake = exec_ready && dec_valid && enable;

    // Decode is advancing
    if (dec_exec_handshake) begin
        // Decode is taking instr from fifo
        if (instr_in_fifo) begin 
            instr_fifo_get = 1;
            // Store instr if there is one coming
            if (instr_handshake) instr_fifo_add = 1;
        end
        // else Decode is taking directly from bus
    end
    // Cannot advance
    else begin 
        // Store instr if there is one coming
        if (instr_handshake) instr_fifo_add = 1;
    end
end

always_ff @(posedge clk) begin
    if (!resetn) begin 
        pc <= RESET_PC;
        dec_exec_buff.control <= create_nop_ctrl();
    end 
    else if (enable) begin 
        // Flush the buffer
        if (flush_bus.op != NO_FLUSH) begin 
            pc <= flush_bus.to;
            dec_exec_buff.control <= create_nop_ctrl();
        end
        else if (exec_ready) begin
            // Instruction was decoded
            if (dec_valid) begin 
                pc <= pc4;
                dec_exec_buff <= ibuff;
            end
            // Exec its ready but no instruction decoded, send bubble
            else dec_exec_buff.control <= create_nop_ctrl();
        end
    end
end

endmodule

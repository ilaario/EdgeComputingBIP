/* verilator lint_off UNUSEDPARAM */
/* verilator lint_off UNUSEDSIGNAL */

module tricycle 
import tricycle_pkg::*;
(
    input logic clk, resetn, enable,
    // Instruction Request
    output mem_request_t instr_mem_req,
    input l32 instr_data, logic instr_valid,
    // Data Request
    output mem_request_t data_mem_req,
    input l32 mem_data, logic mem_data_valid
);

logic dec_ready;
fetch_dec_buff_t fetch_dec_buff;

logic exec_ready;
dec_exec_buff_t dec_exec_buff;

flush_bus_t flush_bus;

rv_reg_id_t [1:0] rf_read_ids;
l32 [1:0] rf_data;
rf_write_request_t rf_write_req;

logic instr_ret;

reg_file rf (
    .clk(clk),
    .rs(rf_read_ids), .o(rf_data),
    .write_request(rf_write_req)
);

fetch fetch (
    .clk(clk), .resetn(resetn), .enable(enable),
    .instr_req(instr_mem_req), .req_ack(1),
    .dec_ready(dec_ready), .fetch_dec_buff(fetch_dec_buff),
    .flush_bus(flush_bus)
);

decode decode (
    .clk(clk), .resetn(resetn), .enable(enable),
    .instr(instr_data), .instr_req_done(instr_valid),
    .rf_read_ids(rf_read_ids), .rf_data(rf_data),
    .fetch_dec_buff(fetch_dec_buff), .dec_ready(dec_ready),
    .exec_ready(exec_ready), .dec_exec_buff(dec_exec_buff),
    .rf_write_req(rf_write_req),
    .flush_bus(flush_bus)
);

execute execute (
    .clk(clk), .resetn(resetn), .enable(enable),
    .dec_data(dec_exec_buff), .exec_ready(exec_ready),
    .data_req(data_mem_req), .data_req_ack(1), 
    .mem_data(mem_data), .data_req_done(mem_data_valid),
    .rf_req_reg(rf_write_req),
    .flush_bus(flush_bus)
);

endmodule

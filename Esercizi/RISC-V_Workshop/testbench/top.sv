
/* verilator lint_off UNUSEDSIGNAL */

module top
import tricycle_pkg::*;
(
    input logic clk, resetn
);

mem_request_t instr_mem_req;
mem_request_t data_mem_req;

logic instr_valid;
l32 instr_data;

logic mem_data_valid;
l32 mem_data;

import "DPI-C" function int mem_dpi(int addr, int data, int op);

always_ff @(posedge clk) begin
    if (!resetn) begin 
        instr_valid <= 0;
        mem_data_valid <= 0;
    end
    else begin 
    
        if (instr_valid) instr_valid <= 0;
        if (mem_data_valid) mem_data_valid <= 0;

        if (instr_mem_req.op == MEM_LW) begin 
            instr_data <= mem_dpi(instr_mem_req.addr, instr_mem_req.data, int'(instr_mem_req.op));
            instr_valid <= 1;
        end

        if (data_mem_req.op != MEM_NOP) begin 
            mem_data <= mem_dpi(data_mem_req.addr, data_mem_req.data, int'(data_mem_req.op));
            mem_data_valid <= 1;
        end

    end
end



tricycle core (
    .clk(clk), .resetn(resetn), .enable(1),
    // Instruction
    .instr_mem_req(instr_mem_req), .instr_valid(instr_valid), .instr_data(instr_data),
    .data_mem_req(data_mem_req), .mem_data_valid(mem_data_valid), .mem_data(mem_data)
);

endmodule


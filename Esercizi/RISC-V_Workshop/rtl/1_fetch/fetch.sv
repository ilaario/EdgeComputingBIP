module fetch 
import tricycle_pkg::*;
(
    input logic clk, resetn, enable,

    // Instr Bus
    output mem_request_t instr_req,
    input logic req_ack,

    // Pipeline
    input logic dec_ready,
    output fetch_dec_buff_t fetch_dec_buff,

    /* verilator lint_off UNUSEDSIGNAL */
    input flush_bus_t flush_bus
    /* verilator lint_on UNUSEDSIGNAL */
);

l32 pc, pc4;
assign pc4 = pc + 4;

always_comb begin 
    instr_req.addr = pc;
    instr_req.data = 0;

    if (dec_ready && enable) instr_req.op = MEM_LW;
    else instr_req.op = MEM_NOP;
end

logic fetch_done;
assign fetch_done = req_ack && dec_ready;

always_ff @(posedge clk) begin
    if (!resetn) begin 
        pc <= RESET_PC;
        fetch_dec_buff.valid <= 0;
    end
    else if (enable) begin
        if (flush_bus.op != NO_FLUSH) begin 
            pc <= flush_bus.to;
            fetch_dec_buff.valid <= 0;
        end
        else if (fetch_done) begin 
            pc <= pc4;
            fetch_dec_buff.valid <= 1;
        end
    end
end


endmodule


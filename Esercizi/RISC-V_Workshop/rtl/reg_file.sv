
/* 
 Register file, 32 registers
 - x0 is readonly 0
 - Generic number of read ports (default 4)
 - 1 Write port
*/

module reg_file
import tricycle_pkg::*;
(
    input logic clk,
    // Read ports
    input rv_reg_id_t [1:0] rs,
    output l32 [1:0] o,
    // Write port
    input rf_write_request_t write_request
);

l32 register_file [32] /*verilator public*/;

// Write logic
always_ff @(posedge clk) begin
    if (write_request.write_enable) begin
        register_file[write_request.id] <= write_request.data;
    end
    // x0 is always 0
    register_file[0] <= 0;
end

// Read logic
always_comb begin
    for(int idx = 0; idx < 2; idx = idx + 1) begin
        o[idx] = register_file[rs[idx]];
    end
end

endmodule


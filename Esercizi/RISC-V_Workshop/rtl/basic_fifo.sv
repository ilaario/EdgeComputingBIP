module basic_fifo 
import tricycle_pkg::*;
# (
    parameter int SIZE = 2,
    parameter int DSIZE = 32,
    // Derived parameters
    parameter int PTR_SIZE = clamp0($clog2(SIZE) - 1),
    parameter int COUNT_SIZE = $clog2(SIZE)
) 
(
    input logic clk, resetn, flush,
    // Status
    output logic [COUNT_SIZE: 0] nfree, count,
    // Write port
    input logic add,
    input logic [DSIZE - 1: 0] i_data,
    // Read port
    input logic get,
    output logic [DSIZE - 1: 0] o_data
);

logic [SIZE - 1:0][DSIZE - 1: 0] buff;

typedef logic [PTR_SIZE: 0] ptr_t;
ptr_t wptr, rptr;

typedef logic [COUNT_SIZE: 0] count_t;
count_t icount;

always_comb begin 
    // Output nfree
    nfree = count_t'(SIZE) - count;
    
    // Calculate internal count
    if (add && get) icount = count;
    else if (add) icount = count + 1;
    else if (get) icount = count - 1;
    else icount = count;

    // Read output
    o_data = buff[rptr];
end

// Pointers logic
always_ff @(posedge clk) begin 
    if (flush || !resetn) begin
        wptr <= 0;
        rptr <= 0;
        count <= 0;
    end
    else begin
        if (add) begin
            buff[wptr] <= i_data;
            wptr <= wptr + 1;
        end
        if (get) begin
            rptr <= rptr + 1;
        end
        count <= icount;
    end
end

endmodule

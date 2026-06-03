
module branch
import tricycle_pkg::*;
(
    input l32 op1, op2,
    input branch_op_t branch_op,
    output logic do_branch
);

logic eq, lt, ltu;

// Comparators
always_comb begin
    eq = (op1 == op2);
    lt = ($signed(op1) < $signed(op2));
    ltu = (op1 < op2);
end

// Branch decision
always_comb begin
    case (branch_op)
        OP_BEQ: do_branch = eq;
        OP_BNE: do_branch = ~eq;
        OP_BLT: do_branch = lt;
        OP_BGE: do_branch = ~lt;
        OP_BLTU: do_branch = ltu;
        OP_BGEU: do_branch = ~ltu;
        OP_J: do_branch = 1;
        default: do_branch = 0;
    endcase
end

endmodule

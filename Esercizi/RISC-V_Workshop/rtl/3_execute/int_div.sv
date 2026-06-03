// 32 bit integer division and remainder unit

module int_div
import tricycle_pkg::*;
(
    input l32 op1, op2,
    input div_op_t opsel,
    output l32 result
);

localparam l32 SIGNED_OVERFLOW_DIVIDEND = 32'h80000000;
localparam l32 SIGNED_OVERFLOW_DIVISOR = 32'hffffffff;

logic div_by_zero, signed_overflow;

always_comb begin
    div_by_zero = (op2 == 0);
    signed_overflow = (op1 == SIGNED_OVERFLOW_DIVIDEND && op2 == SIGNED_OVERFLOW_DIVISOR);

    unique case (opsel)
        DIV_OP_DIV: begin
            if (div_by_zero) result = 32'hffffffff;
            else if (signed_overflow) result = SIGNED_OVERFLOW_DIVIDEND;
            else result = l32'($signed(op1) / $signed(op2));
        end

        DIV_OP_DIVU: begin
            if (div_by_zero) result = 32'hffffffff;
            else result = op1 / op2;
        end

        DIV_OP_REM: begin
            if (div_by_zero) result = op1;
            else if (signed_overflow) result = 0;
            else result = l32'($signed(op1) % $signed(op2));
        end

        DIV_OP_REMU: begin
            if (div_by_zero) result = op1;
            else result = op1 % op2;
        end
    endcase
end

endmodule

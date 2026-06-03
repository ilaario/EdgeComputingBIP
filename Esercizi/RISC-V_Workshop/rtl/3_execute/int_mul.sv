// 32 bit integer multiplication unit

module int_mul
import tricycle_pkg::*;
(
    input l32 op1, op2,
    input mul_op_t opsel,
    output l32 result
);

function automatic logic [63:0] mul_signed_signed(input l32 a, b);
    logic signed [63:0] a64, b64;
    begin
        a64 = $signed({{32{a[31]}}, a});
        b64 = $signed({{32{b[31]}}, b});
        mul_signed_signed = a64 * b64;
    end
endfunction

function automatic logic [63:0] mul_signed_unsigned(input l32 a, b);
    logic signed [63:0] a64, b64;
    begin
        a64 = $signed({{32{a[31]}}, a});
        b64 = $signed({32'b0, b});
        mul_signed_unsigned = a64 * b64;
    end
endfunction

function automatic logic [63:0] mul_unsigned_unsigned(input l32 a, b);
    logic [63:0] a64, b64;
    begin
        a64 = {32'b0, a};
        b64 = {32'b0, b};
        mul_unsigned_unsigned = a64 * b64;
    end
endfunction

logic [63:0] product;

always_comb begin
    unique case (opsel)
        MUL_OP_MUL: product = mul_signed_signed(op1, op2);
        MUL_OP_MULH: product = mul_signed_signed(op1, op2);
        MUL_OP_MULHSU: product = mul_signed_unsigned(op1, op2);
        MUL_OP_MULHU: product = mul_unsigned_unsigned(op1, op2);
    endcase

    if (opsel == MUL_OP_MUL) result = product[31:0];
    else result = product[63:32];
end

endmodule

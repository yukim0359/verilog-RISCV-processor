`include "define.vh"

module judge_br(
    input wire [5:0] alucode,
    input wire [31:0] op1,
    input wire [31:0] op2,
    output wire br_taken
);

    wire is_jal_jalr = (alucode == `ALU_JAL | alucode == `ALU_JALR);

    wire is_beq   = (alucode == `ALU_BEQ);
    wire is_bne   = (alucode == `ALU_BNE);
    wire is_blt   = (alucode == `ALU_BLT);
    wire is_bltu  = (alucode == `ALU_BLTU);
    wire is_bge   = (alucode == `ALU_BGE);
    wire is_bgeu  = (alucode == `ALU_BGEU);

    wire is_equal         = (op1 == op2);
    wire is_less_unsigned = (op1 < op2);
    wire is_less_signed   = ($signed(op1) < $signed(op2));
    // wire is_less_signed = (op1[31] != op2[31]) ? op1[31] : is_less_unsigned;

    /*assign br_taken = 
            (is_bltu)          ? is_less_unsigned : 
            (is_bgeu)          ? !is_less_unsigned :
            (is_blt)           ? is_less_signed :
            (is_bge)           ? !is_less_signed : 
            (is_beq)           ? is_equal : 
            (is_bne)           ? !is_equal :
            (is_jal | is_jalr) ? 1'b1 :
                                 1'b0;*/
    assign br_taken = 
            (is_bltu & is_less_unsigned) |
            (is_bgeu & !is_less_unsigned) |
            (is_blt & is_less_signed) |
            (is_bge & !is_less_signed) |
            (is_beq & is_equal) |
            (is_bne & !is_equal) |
            (is_jal_jalr);

endmodule
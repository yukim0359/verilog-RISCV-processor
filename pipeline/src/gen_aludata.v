module gen_aludata(
    input wire [31:0] imm,                    // 即値
    input wire [1:0] aluop1_type,             // ALUの入力タイプ1
    input wire [1:0] aluop2_type,             // ALUの入力タイプ2
    input wire [16:0] pc,                     // ALUにわたすため
    input wire [31:0] reg_data1,
    input wire [31:0] reg_data2,
    output wire [31:0] op1,                   // ALUに渡すオペランド1
    output wire [31:0] op2                    // ALUに渡すオペランド2
);

    assign op1 = (aluop1_type == `OP_TYPE_REG) ? reg_data1 :   // レジスタの値
                 (aluop1_type == `OP_TYPE_IMM) ? imm :         // 即値
                 (aluop1_type == `OP_TYPE_PC)  ? {17'b0, pc}:  // PC 
                 32'b0;

    assign op2 = (aluop2_type == `OP_TYPE_REG) ? reg_data2 :   // レジスタの値
                 (aluop2_type == `OP_TYPE_IMM) ? imm :         // 即値
                 (aluop2_type == `OP_TYPE_PC)  ? {17'b0, pc}:  // PC 
                 32'b0;

endmodule

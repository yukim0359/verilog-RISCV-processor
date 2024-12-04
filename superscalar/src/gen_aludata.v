module gen_aludata(
    input wire [31:0] imm,
    input wire [1:0] aluop1_type,
    input wire [1:0] aluop2_type,
    input wire [14:0] pc,
    input wire [31:0] reg_data1,
    input wire [31:0] reg_data2,
    output wire [31:0] op1,
    output wire [31:0] op2
);

    assign op1 = (aluop1_type == `OP_TYPE_REG) ? reg_data1 :
                 (aluop1_type == `OP_TYPE_IMM) ? imm :
                 (aluop1_type == `OP_TYPE_PC)  ? {17'b0, pc} :
                 32'b0;

    assign op2 = (aluop2_type == `OP_TYPE_REG) ? reg_data2 :
                 (aluop2_type == `OP_TYPE_IMM) ? imm : 
                 (aluop2_type == `OP_TYPE_PC)  ? {17'b0, pc} :
                 32'b0;

endmodule

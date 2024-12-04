module stage_X(
    input wire clk,
    input wire reset,
    input wire [5:0] alucode,
    input wire [31:0] reg_data1, reg_data2, imm,
    input wire [14:0] pc, pc_added_imm, pc_added_four,
    input wire [1:0] aluop1_type, aluop2_type,
    input wire is_load, is_store, is_jalr, 
    input wire w_miss, wait_load,
    input wire D_X_valid,
    input wire other_busy,
    output wire [31:0] alu_result,
    output wire br_taken, busy,
    output wire [14:0] t_pc
);

    wire [31:0] op1, op2;

    gen_aludata gen_aludata(
        .imm(imm), 
        .aluop1_type(aluop1_type),
        .aluop2_type(aluop2_type),
        .pc(pc),
        .reg_data1(reg_data1),
        .reg_data2(reg_data2),
        .op1(op1),                 
        .op2(op2)
    );

    wire valid = D_X_valid & !w_miss & !wait_load;

    alu alu (
        .clk(clk),
        .reset(reset),
        .valid(valid),
        .alucode(alucode),
        .reg_data1(reg_data1),
        .reg_data2(reg_data2),
        .op1(op1),
        .op2(op2),
        .is_load(is_load),
        .is_store(is_store),
        .other_busy(other_busy),
        .alu_result(alu_result),
        .busy(busy)
    );

    judge_br judge_br(
        .alucode(alucode),
        .op1(reg_data1),
        .op2(reg_data2),
        .br_taken(br_taken)
    );

    wire [14:0] jalr_t_pc = reg_data1 + imm;

    assign t_pc = (is_jalr) ? jalr_t_pc : (br_taken) ? pc_added_imm : pc_added_four;

endmodule
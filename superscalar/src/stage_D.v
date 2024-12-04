module stage_D(
    input wire [31:0] instruction1, instruction2,
    output wire [4:0] rs1, rs2, rs3, rs4,
    output wire [4:0] rd1, rd2,
    output wire [31:0] imm1, imm2,
    output wire [5:0] alucode1, alucode2,
    output wire [1:0] aluop1_type1, aluop2_type1, aluop1_type2, aluop2_type2,
    output wire reg_we1, reg_we2,
    output wire is_load1, is_load2,
    output wire is_store1, is_store2, 
    output wire is_br1, is_br2,
    output wire is_jalr1, is_jalr2, 
    output wire is_halt1, is_halt2,
    output wire next_is_single
);

    decode decode1 (
        .ir(instruction1),
        .srcreg1_num(rs1),
        .srcreg2_num(rs2),
        .dstreg_num(rd1),
        .imm(imm1),
        .alucode(alucode1),
        .aluop1_type(aluop1_type1),
        .aluop2_type(aluop2_type1),
        .reg_we(reg_we1),
        .is_load(is_load1),
        .is_store(is_store1),
        .is_br(is_br1),
        .is_jalr(is_jalr1),
        .is_halt(is_halt1)
    );

    decode decode2 (
        .ir(instruction2),
        .srcreg1_num(rs3),
        .srcreg2_num(rs4),
        .dstreg_num(rd2),
        .imm(imm2),
        .alucode(alucode2),
        .aluop1_type(aluop1_type2),
        .aluop2_type(aluop2_type2),
        .reg_we(reg_we2),
        .is_load(is_load2),
        .is_store(is_store2),
        .is_br(is_br2),
        .is_jalr(is_jalr2),
        .is_halt(is_halt2)
    );

    // store → load or store, RAWのいずれかの場合は1つしか実行せず
    wire conflict_store = is_store1 & (is_load2 | is_store2);
    wire conflict_raw = reg_we1 & (rd1 == rs3 | rd1 == rs4);

    assign next_is_single = conflict_store | conflict_raw;

endmodule

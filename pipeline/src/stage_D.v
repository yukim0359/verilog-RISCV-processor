module stage_D(
    input wire [31:0] instruction,
    output wire [4:0] rs1,
    output wire [4:0] rs2,
    output wire [4:0] rd,
    output wire [31:0] imm,
    output wire [5:0] alucode,
    output wire [1:0] aluop1_type,
    output wire [1:0] aluop2_type,
    output wire reg_we,
    output wire is_load,
    output wire is_store,
    output wire is_br,
    output wire is_jalr,
    output wire is_halt
);

    decode decode (
        .ir(instruction),
        .reset(reset),
        .srcreg1_num(rs1),
        .srcreg2_num(rs2),
        .dstreg_num(rd),
        .imm(imm),
        .alucode(alucode),
        .aluop1_type(aluop1_type),
        .aluop2_type(aluop2_type),
        .reg_we(reg_we),
        .is_load(is_load),
        .is_store(is_store),
        .is_br(is_br),
        .is_jalr(is_jalr),
        .is_halt(is_halt)
    );
    
endmodule
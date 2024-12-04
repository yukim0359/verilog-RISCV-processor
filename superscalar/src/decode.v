`include "define.vh"

module decode(
    input  wire [31:0] ir,            // 機械語命令列
    output wire [4:0]  srcreg1_num,   // ソースレジスタ1番号
    output wire [4:0]  srcreg2_num,   // ソースレジスタ2番号
    output wire [4:0]  dstreg_num,    // デスティネーションレジスタ番号
    output wire [31:0] imm,           // 即値
    output wire [5:0]  alucode,       // ALUの演算種別
    output wire [1:0]  aluop1_type,   // ALUの入力タイプ
    output wire [1:0]  aluop2_type,   // ALUの入力タイプ
    output wire        reg_we,        // レジスタ書き込みの有無
    output wire        is_load,       // ロード命令判定フラグ
    output wire        is_store,      // ストア命令判定フラグ
    output wire        is_br,
    output wire        is_jalr,
    output wire        is_halt        // ハルト命令判定フラグ
);

    wire [6:0] opcode = ir[6:0];      // オペコード
    wire [2:0] funct3 = ir[14:12];    // funct3フィールド
    wire [6:0] funct7 = ir[31:25];    // funct7フィールド

    // 各命令タイプを示す信号
    wire is_OPIMM  = (opcode == `OPIMM);
    wire is_OP     = (opcode == `OP);
    wire is_LOAD   = (opcode == `LOAD);
    wire is_STORE  = (opcode == `STORE);
    wire is_BRANCH = (opcode == `BRANCH);
    wire is_LUI    = (opcode == `LUI);
    wire is_AUIPC  = (opcode == `AUIPC);
    wire is_JAL    = (opcode == `JAL);
    wire is_JALR   = (opcode == `JALR);
    
    // funct3 に対応する信号
    wire funct3_is_000 = (funct3 == 3'b000);
    wire funct3_is_001 = (funct3 == 3'b001);
    wire funct3_is_010 = (funct3 == 3'b010);
    wire funct3_is_011 = (funct3 == 3'b011);
    wire funct3_is_100 = (funct3 == 3'b100);
    wire funct3_is_101 = (funct3 == 3'b101);
    wire funct3_is_110 = (funct3 == 3'b110);
    wire funct3_is_111 = (funct3 == 3'b111);

    // funct7 に対応する信号
    wire funct7_is_0000000 = (funct7 == 7'b0000000);
    wire funct7_is_0000001 = (funct7 == 7'b0000001);
    wire funct7_is_0100000 = (funct7 == 7'b0100000);
    wire funct7_is_1111111 = (funct7 == 7'b1111111);

    assign srcreg1_num = (is_LUI | is_JAL | is_AUIPC) ? 5'b0 : ir[19:15];
    assign srcreg2_num = (is_OP | is_STORE | is_BRANCH) ? ir[24:20] : 5'b0;
    assign dstreg_num = (is_STORE | is_BRANCH) ? 5'b0 : ir[11:7];
    assign imm = 
        (is_OPIMM & (funct3_is_000 | funct3_is_010 | funct3_is_011 | funct3_is_100 | funct3_is_110 | funct3_is_111)) ? {{20{ir[31]}}, ir[31:20]} : 
        (is_OPIMM & (funct3_is_001 | funct3_is_101))                                                                 ? {{27{ir[24]}}, ir[24:20]} : 
        (is_LOAD | is_JALR)    ? {{20{ir[31]}}, ir[31:20]} :
        (is_STORE)             ? {{20{ir[31]}}, ir[31:25], ir[11:7]} :
        (is_BRANCH)            ? {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0} : 
        (is_LUI)               ? {ir[31:12], 12'b0} : 
        (is_JAL | is_AUIPC)    ? {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0} : 
                                 32'b0;
                                 
    assign alucode = 
        (is_OPIMM) ?
            (funct3_is_000)                     ? `ALU_ADD :
            (funct3_is_010)                     ? `ALU_SLT :
            (funct3_is_011)                     ? `ALU_SLTU :
            (funct3_is_100)                     ? `ALU_XOR :
            (funct3_is_110)                     ? `ALU_OR :
            (funct3_is_111)                     ? `ALU_AND :
            (funct3_is_001)                     ? `ALU_SLL :
            (funct3_is_101 & funct7_is_0000000) ? `ALU_SRL :
            (funct3_is_101 & funct7_is_0100000) ? `ALU_SRA :
                                                  `ALU_NOP :
        (is_OP) ? 
            (funct7_is_0000001) ? 
                (funct3_is_000) ? `ALU_MUL :
                (funct3_is_001) ? `ALU_MULH :
                (funct3_is_010) ? `ALU_MULHSU :
                (funct3_is_011) ? `ALU_MULHU :
                (funct3_is_100) ? `ALU_DIV :
                (funct3_is_101) ? `ALU_DIVU :
                (funct3_is_110) ? `ALU_REM :
                (funct3_is_111) ? `ALU_REMU : `ALU_NOP :
            (funct7_is_0000000 & funct3_is_000) ? `ALU_ADD :
            (funct7_is_0100000 & funct3_is_000) ? `ALU_SUB :
            (funct3_is_010)                     ? `ALU_SLT :
            (funct3_is_011)                     ? `ALU_SLTU :
            (funct3_is_100)                     ? `ALU_XOR :
            (funct3_is_110)                     ? `ALU_OR :
            (funct3_is_111)                     ? `ALU_AND :
            (funct3_is_001)                     ? `ALU_SLL :
            (funct7_is_0000000 & funct3_is_101) ? `ALU_SRL :
            (funct7_is_0100000 & funct3_is_101) ? `ALU_SRA :
                                                  `ALU_NOP :
        (is_LOAD) ? 
            (funct3_is_000)                     ? `ALU_LB :
            (funct3_is_001)                     ? `ALU_LH :
            (funct3_is_010)                     ? `ALU_LW :
            (funct3_is_100)                     ? `ALU_LBU :
            (funct3_is_101)                     ? `ALU_LHU :
                                                  `ALU_NOP :
        (is_STORE) ?   
            (funct3_is_000)                     ? `ALU_SB :
            (funct3_is_001)                     ? `ALU_SH :
            (funct3_is_010)                     ? `ALU_SW :
                                                  `ALU_NOP :
        (is_BRANCH) ?                                                
            (funct3_is_000)                     ? `ALU_BEQ :
            (funct3_is_001)                     ? `ALU_BNE :
            (funct3_is_100)                     ? `ALU_BLT :
            (funct3_is_101)                     ? `ALU_BGE :
            (funct3_is_110)                     ? `ALU_BLTU :
            (funct3_is_111)                     ? `ALU_BGEU :
                                                  `ALU_NOP :
        (is_LUI)                                ? `ALU_LUI :
        (is_AUIPC)                              ? `ALU_ADD :
        (is_JAL)                                ? `ALU_JAL :
        (is_JALR)                               ? `ALU_JALR :
                                                  `ALU_NOP;

    assign aluop1_type =
        (is_OPIMM | is_OP | is_LOAD | is_STORE | is_BRANCH | is_JALR) ? `OP_TYPE_REG :
        (is_AUIPC)                                                    ? `OP_TYPE_IMM :
                                                                        `OP_TYPE_NONE;

    assign aluop2_type =
        (is_OP | is_BRANCH)                      ? `OP_TYPE_REG :
        (is_OPIMM | is_LOAD | is_STORE | is_LUI) ? `OP_TYPE_IMM :
        (is_JAL | is_JALR | is_AUIPC)            ? `OP_TYPE_PC :
                                                   `OP_TYPE_NONE;

    assign reg_we = (dstreg_num != 5'b0);
        
    assign is_load = is_LOAD;

    assign is_store = is_STORE;

    assign is_br = (is_BRANCH | is_JAL | is_JALR);

    assign is_jalr = is_JALR;

    assign is_halt = !(is_OPIMM | is_OP | is_LOAD | is_STORE | is_BRANCH | is_LUI | is_AUIPC | is_JAL | is_JALR);

endmodule

/*`include "define.vh"

module decode(
    input  wire [31:0] ir,            // 機械語命令列
    output wire [4:0]  srcreg1_num,   // ソースレジスタ1番号
    output wire [4:0]  srcreg2_num,   // ソースレジスタ2番号
    output wire [4:0]  dstreg_num,    // デスティネーションレジスタ番号
    output wire [31:0] imm,           // 即値
    output wire [5:0]  alucode,       // ALUの演算種別
    output wire [1:0]  aluop1_type,   // ALUの入力タイプ
    output wire [1:0]  aluop2_type,   // ALUの入力タイプ
    output wire        reg_we,        // レジスタ書き込みの有無
    output wire        is_load,       // ロード命令判定フラグ
    output wire        is_store,      // ストア命令判定フラグ
    output wire        is_br,         // branchする可能性がある命令判定フラグ
    output wire        is_jalr,       // JALR命令判定フラグ
    output wire        is_halt        // ハルト命令判定フラグ
);

    wire [6:0] opcode = ir[6:0];      // オペコード
    wire [2:0] funct3 = ir[14:12];    // funct3フィールド
    wire [6:0] funct7 = ir[31:25];    // funct7フィールド

    // 各命令タイプを示す信号
    wire is_OPIMM  = (opcode == `OPIMM);
    wire is_OP     = (opcode == `OP);
    wire is_LOAD   = (opcode == `LOAD);
    wire is_STORE  = (opcode == `STORE);
    wire is_BRANCH = (opcode == `BRANCH);
    wire is_LUI    = (opcode == `LUI);
    wire is_AUIPC  = (opcode == `AUIPC);
    wire is_JAL    = (opcode == `JAL);
    wire is_JALR   = (opcode == `JALR);
    
    // funct3 に対応する信号
    wire funct3_is_000 = (funct3 == 3'b000);
    wire funct3_is_001 = (funct3 == 3'b001);
    wire funct3_is_010 = (funct3 == 3'b010);
    wire funct3_is_011 = (funct3 == 3'b011);
    wire funct3_is_100 = (funct3 == 3'b100);
    wire funct3_is_101 = (funct3 == 3'b101);
    wire funct3_is_110 = (funct3 == 3'b110);
    wire funct3_is_111 = (funct3 == 3'b111);

    // funct7 に対応する信号
    wire funct7_is_0000000 = (funct7 == 7'b0000000);
    wire funct7_is_0100000 = (funct7 == 7'b0100000);
    wire funct7_is_1111111 = (funct7 == 7'b1111111);

    assign srcreg1_num = (is_LUI | is_JAL | is_AUIPC) ? 5'b0 : ir[19:15];
    assign srcreg2_num = (is_OP | is_STORE | is_BRANCH) ? ir[24:20] : 5'b0;
    assign dstreg_num  = (is_STORE | is_BRANCH) ? 5'b0 : ir[11:7];
    assign imm = 
        (is_OPIMM & (funct3_is_000 | funct3_is_010 | funct3_is_011 | funct3_is_100 | funct3_is_110 | funct3_is_111)) ? {{20{ir[31]}}, ir[31:20]} : 
        (is_OPIMM & (funct3_is_001 | funct3_is_101))                                                                 ? {{27{ir[24]}}, ir[24:20]} : 
        (is_LOAD | is_JALR)    ? {{20{ir[31]}}, ir[31:20]} :
        (is_STORE)             ? {{20{ir[31]}}, ir[31:25], ir[11:7]} :
        (is_BRANCH)            ? {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0} : 
        (is_LUI)               ? {ir[31:12], 12'b0} : 
        (is_JAL | is_AUIPC)    ? {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0} : 
                                 32'b0;
           
    assign alucode = 
        (is_OPIMM) ?
            (funct3_is_000)                     ? `ALU_ADD :
            (funct3_is_010)                     ? `ALU_SLT :
            (funct3_is_011)                     ? `ALU_SLTU :
            (funct3_is_100)                     ? `ALU_XOR :
            (funct3_is_110)                     ? `ALU_OR :
            (funct3_is_111)                     ? `ALU_AND :
            (funct3_is_001)                     ? `ALU_SLL :
            (funct3_is_101 & funct7_is_0000000) ? `ALU_SRL :
            (funct3_is_101 & funct7_is_0100000) ? `ALU_SRA :
                                                  `ALU_NOP :
        (is_OP) ? 
            (funct7_is_0000000 & funct3_is_000) ? `ALU_ADD :
            (funct7_is_0100000 & funct3_is_000) ? `ALU_SUB :
            (funct3_is_001)                     ? `ALU_SLL :
            (funct3_is_010)                     ? `ALU_SLT :
            (funct3_is_011)                     ? `ALU_SLTU :
            (funct3_is_100)                     ? `ALU_XOR :
            (funct7_is_0000000 & funct3_is_101) ? `ALU_SRL :
            (funct7_is_0100000 & funct3_is_101) ? `ALU_SRA :
            (funct3_is_110)                     ? `ALU_OR :
            (funct3_is_111)                     ? `ALU_AND :
                                                  `ALU_NOP :
        (is_LOAD) ?                                        
            (funct3_is_000)                     ? `ALU_LB :
            (funct3_is_001)                     ? `ALU_LH :
            (funct3_is_010)                     ? `ALU_LW :
            (funct3_is_100)                     ? `ALU_LBU :
            (funct3_is_101)                     ? `ALU_LHU :
                                                  `ALU_NOP :
        (is_STORE) ?   
            (funct3_is_000)                     ? `ALU_SB :
            (funct3_is_001)                     ? `ALU_SH :
            (funct3_is_010)                     ? `ALU_SW :
                                                  `ALU_NOP :
        (is_BRANCH) ?                                                
            (funct3_is_000)                     ? `ALU_BEQ :
            (funct3_is_001)                     ? `ALU_BNE :
            (funct3_is_100)                     ? `ALU_BLT :
            (funct3_is_101)                     ? `ALU_BGE :
            (funct3_is_110)                     ? `ALU_BLTU :
            (funct3_is_111)                     ? `ALU_BGEU :
                                                  `ALU_NOP :
        (is_LUI)                                ? `ALU_LUI :
        (is_AUIPC)                              ? `ALU_ADD :
        (is_JAL)                                ? `ALU_JAL :
        (is_JALR)                               ? `ALU_JALR :
                                                  `ALU_NOP;

    assign aluop1_type =
        (is_OPIMM | is_OP | is_LOAD | is_STORE | is_BRANCH | is_JALR) ? `OP_TYPE_REG :
        (is_AUIPC)                                                    ? `OP_TYPE_IMM :
                                                                        `OP_TYPE_NONE;
                         
    assign aluop2_type =
        (is_OP | is_BRANCH)                      ? `OP_TYPE_REG :
        (is_OPIMM | is_LOAD | is_STORE | is_LUI) ? `OP_TYPE_IMM :
        (is_JAL | is_JALR | is_AUIPC)            ? `OP_TYPE_PC :
                                                   `OP_TYPE_NONE;

    assign reg_we = (dstreg_num != 5'b0);
        
    assign is_load = is_LOAD;

    assign is_store = is_STORE;

    assign is_br = (is_BRANCH | is_JAL | is_JALR);

    assign is_jalr = is_JALR;

    assign is_halt = !(is_OPIMM | is_OP | is_LOAD | is_STORE | is_BRANCH | is_LUI | is_AUIPC | is_JAL | is_JALR);

endmodule
*/
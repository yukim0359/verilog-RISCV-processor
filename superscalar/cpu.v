`include "define.vh"

module cpu(
    input wire sysclk, 
    input wire cpu_resetn, 
    output wire uart_tx
);

    // Stage Fからの信号
    wire [14:0] pc1, pc2;
    wire [31:0] w_instruction1, w_instruction2;

    // Stage Dからの信号
    wire [4:0] rs1, rs2, rs3, rs4, rd1, rd2;
    wire [31:0] imm1, imm2;
    wire [5:0] alucode1, alucode2;
    wire [1:0] aluop1_type1, aluop2_type1, aluop1_type2, aluop2_type2;
    wire reg_we1, is_load1, is_store1, is_br1, is_jalr1, is_halt1,
         reg_we2, is_load2, is_store2, is_br2, is_jalr2, is_halt2;
    wire next_is_single;

    // Stage Xからの信号
    wire [31:0] alu_result1, alu_result2;
    wire [14:0] t_pc1, t_pc2;
    wire br_taken1, br_taken2, busy1, busy2;

    // Stage Mからの信号
    wire [31:0] w_mem_data1, w_mem_data2;
    wire [4:0] byte_offset1, byte_offset2;
    wire is_hardware1, is_hardware2;

    // Stage Wからの信号
    wire [31:0] wb_data1, wb_data2;

    // レジスタファイル
    wire [31:0] reg_data1, reg_data2, reg_data3, reg_data4;

    // Stage間パイプラインレジスタ定義
    reg [14:0] F_D_pc1, F_D_pc2;
    reg F_D_valid1, F_D_valid2;

    reg [31:0] D_X_imm1, D_X_reg_data1, D_X_reg_data2,
               D_X_imm2, D_X_reg_data3, D_X_reg_data4;
    reg [14:0] D_X_pc1, D_X_pc2, D_X_pc_added_imm1, D_X_pc_added_four1,  D_X_pc_added_imm2, D_X_pc_added_four2;
    reg [5:0] D_X_alucode1, D_X_alucode2;
    reg [4:0] D_X_rs1, D_X_rs2, D_X_rs3, D_X_rs4, D_X_rd1, D_X_rd2;
    reg [1:0] D_X_aluop1_type1, D_X_aluop2_type1, D_X_aluop1_type2, D_X_aluop2_type2;
    reg D_X_reg_we1, D_X_is_load1, D_X_is_store1, D_X_is_halt1, D_X_is_br1, D_X_is_jalr1,
        D_X_reg_we2, D_X_is_load2, D_X_is_store2, D_X_is_halt2, D_X_is_br2, D_X_is_jalr2;
    reg D_X_valid1, D_X_valid2;

    reg [31:0] X_M_alu_result1, X_M_write_data1, X_M_alu_result2, X_M_write_data2;
    reg [14:0] X_M_pc1, X_M_pc2, X_M_t_pc1, X_M_t_pc2;
    reg [5:0] X_M_alucode1, X_M_alucode2;
    reg [4:0] X_M_rd1, X_M_rd2;
    reg X_M_reg_we1, X_M_is_load1, X_M_is_store1,
        X_M_reg_we2, X_M_is_load2, X_M_is_store2;
    reg X_M_is_br1, X_M_is_br2, X_M_br_taken1, X_M_br_taken2;
    reg X_M_valid1, X_M_valid2;

    reg [31:0] M_W_alu_result1, M_W_alu_result2;
    reg [5:0] M_W_alucode1, M_W_alucode2;
    reg [4:0] M_W_rd1, M_W_rd2, M_W_byte_offset1, M_W_byte_offset2;
    reg M_W_reg_we1, M_W_reg_we2;
    reg M_W_is_hardware1, M_W_is_hardware2;
    reg M_W_valid1, M_W_valid2;

    // HardwareCounter
    wire [31:0] hc_OUT_data;

    // uart
    wire [7:0] uart_IN_data;
    wire uart_we;
    wire uart_OUT_data;

    // 先にあるステージのrdがrs1と一致するか
    // 4(=rsの数) * 4(=Mのrd2つとWのrd2つ) = 16パターン
    // 後のforwarding判定で用いる
    wire rs1_match_Mrd1 = (X_M_rd1 == D_X_rs1) & X_M_reg_we1;
    wire rs1_match_Mrd2 = (X_M_rd2 == D_X_rs1) & X_M_reg_we2;
    wire rs1_match_Wrd1 = (M_W_rd1 == D_X_rs1) & M_W_reg_we1;
    wire rs1_match_Wrd2 = (M_W_rd2 == D_X_rs1) & M_W_reg_we2;
    wire rs2_match_Mrd1 = (X_M_rd1 == D_X_rs2) & X_M_reg_we1;
    wire rs2_match_Mrd2 = (X_M_rd2 == D_X_rs2) & X_M_reg_we2;
    wire rs2_match_Wrd1 = (M_W_rd1 == D_X_rs2) & M_W_reg_we1;
    wire rs2_match_Wrd2 = (M_W_rd2 == D_X_rs2) & M_W_reg_we2;
    wire rs3_match_Mrd1 = (X_M_rd1 == D_X_rs3) & X_M_reg_we1;
    wire rs3_match_Mrd2 = (X_M_rd2 == D_X_rs3) & X_M_reg_we2;
    wire rs3_match_Wrd1 = (M_W_rd1 == D_X_rs3) & M_W_reg_we1;
    wire rs3_match_Wrd2 = (M_W_rd2 == D_X_rs3) & M_W_reg_we2;
    wire rs4_match_Mrd1 = (X_M_rd1 == D_X_rs4) & X_M_reg_we1;
    wire rs4_match_Mrd2 = (X_M_rd2 == D_X_rs4) & X_M_reg_we2;
    wire rs4_match_Wrd1 = (M_W_rd1 == D_X_rs4) & M_W_reg_we1;
    wire rs4_match_Wrd2 = (M_W_rd2 == D_X_rs4) & M_W_reg_we2;

    // valid & loadを判定
    // 後のload use判定で用いる
    wire X_M_valid_and_load1 = X_M_valid1 & X_M_is_load1;
    wire X_M_valid_and_load2 = X_M_valid2 & X_M_is_load2;

    // forwardingの判定
    wire M_valid_and_notload1 = X_M_valid1 & !X_M_is_load1;
    wire M_valid_and_notload2 = X_M_valid2 & !X_M_is_load2;
    wire W_valid1 = M_W_valid1;
    wire W_valid2 = M_W_valid2;
    wire fwd_toReg1_fromM1 = rs1_match_Mrd1 & M_valid_and_notload1;
    wire fwd_toReg1_fromM2 = rs1_match_Mrd2 & M_valid_and_notload2;
    wire fwd_toReg1_fromW1 = rs1_match_Wrd1 & W_valid1;
    wire fwd_toReg1_fromW2 = rs1_match_Wrd2 & W_valid2;
    wire fwd_toReg2_fromM1 = rs2_match_Mrd1 & M_valid_and_notload1;
    wire fwd_toReg2_fromM2 = rs2_match_Mrd2 & M_valid_and_notload2;
    wire fwd_toReg2_fromW1 = rs2_match_Wrd1 & W_valid1;
    wire fwd_toReg2_fromW2 = rs2_match_Wrd2 & W_valid2;
    wire fwd_toReg3_fromM1 = rs3_match_Mrd1 & M_valid_and_notload1;
    wire fwd_toReg3_fromM2 = rs3_match_Mrd2 & M_valid_and_notload2;
    wire fwd_toReg3_fromW1 = rs3_match_Wrd1 & W_valid1;
    wire fwd_toReg3_fromW2 = rs3_match_Wrd2 & W_valid2;
    wire fwd_toReg4_fromM1 = rs4_match_Mrd1 & M_valid_and_notload1;
    wire fwd_toReg4_fromM2 = rs4_match_Mrd2 & M_valid_and_notload2;
    wire fwd_toReg4_fromW1 = rs4_match_Wrd1 & W_valid1;
    wire fwd_toReg4_fromW2 = rs4_match_Wrd2 & W_valid2;

    // forwardingの優先順位は M2->M1->W2->W1->なし
    wire [31:0] reg_data1_forward, reg_data2_forward, reg_data3_forward, reg_data4_forward;
    assign reg_data1_forward = 
        (fwd_toReg1_fromM2) ? X_M_alu_result2 :
        (fwd_toReg1_fromM1) ? X_M_alu_result1 :
        (fwd_toReg1_fromW2) ? wb_data2 :
        (fwd_toReg1_fromW1) ? wb_data1 : D_X_reg_data1;
    assign reg_data2_forward = 
        (fwd_toReg2_fromM2) ? X_M_alu_result2 :
        (fwd_toReg2_fromM1) ? X_M_alu_result1 :
        (fwd_toReg2_fromW2) ? wb_data2 :
        (fwd_toReg2_fromW1) ? wb_data1 : D_X_reg_data2;
    assign reg_data3_forward = 
        (fwd_toReg3_fromM2) ? X_M_alu_result2 :
        (fwd_toReg3_fromM1) ? X_M_alu_result1 :
        (fwd_toReg3_fromW2) ? wb_data2 :
        (fwd_toReg3_fromW1) ? wb_data1 : D_X_reg_data3;
    assign reg_data4_forward = 
        (fwd_toReg4_fromM2) ? X_M_alu_result2 :
        (fwd_toReg4_fromM1) ? X_M_alu_result1 :
        (fwd_toReg4_fromW2) ? wb_data2 :
        (fwd_toReg4_fromW1) ? wb_data1 : D_X_reg_data4;


    // Load-Use判定
    wire wait_load_rs12 = D_X_valid1 & (X_M_valid_and_load1 & (rs1_match_Mrd1 | rs2_match_Mrd1)) | (X_M_valid_and_load2 & (rs1_match_Mrd2 | rs2_match_Mrd2));
    wire wait_load_rs34 = D_X_valid2 & (X_M_valid_and_load1 & (rs3_match_Mrd1 | rs4_match_Mrd1)) | (X_M_valid_and_load2 & (rs3_match_Mrd2 | rs4_match_Mrd2));
    wire wait_load      = wait_load_rs12 | wait_load_rs34;

    // stall
    wire stall = wait_load | busy1 | busy2;

    // そのステージでwrite backを行うか
    wire do_wb1 = M_W_valid1 & M_W_reg_we1;
    wire do_wb2 = M_W_valid2 & M_W_reg_we2;
    wire do_wb  = do_wb1 | do_wb2;

    // 分岐予測
    wire [14:0] pred_pc1, pred_pc2;
    wire btb_hit1, pht_ret1, btb_hit2, pht_ret2;
    wire pred_br_taken1 = btb_hit1 & pht_ret1;
    wire pred_br_taken2 = btb_hit2 & pht_ret2;
    wire w_miss1 = X_M_valid1 & (X_M_valid2 & (X_M_pc2[14:2] != X_M_t_pc1[14:2]) | (!X_M_valid2 & D_X_valid1 & (D_X_pc1[14:2] != X_M_t_pc1[14:2])));
    wire w_miss2 = X_M_valid2 & D_X_valid1 & (D_X_pc1[14:2] != X_M_t_pc2[14:2]);
    wire w_miss  = w_miss1 | w_miss2;
    wire [14:0] pc_intoF1 = (w_miss1) ? X_M_t_pc1 : (w_miss2) ? X_M_t_pc2 : (pred_br_taken1) ? pred_pc1 : F_D_pc2 + 4;
    wire [14:0] pc_intoF2 = (pred_br_taken2) ? pred_pc2 : pc_intoF1 + 4;

    wire btb_we1 = X_M_valid1 & X_M_is_br1;
    wire btb_we2 = X_M_valid2 & X_M_is_br2 & !w_miss1;
    wire btb_we  = btb_we1 | btb_we2;
    // 分岐予測器に書き込むデータは新しいものを優先する
    wire [4:0] btb_waddr = (btb_we2) ? X_M_pc2[6:2] : X_M_pc1[6:2];
    wire [23:0] btb_wd = (btb_we2) ? {1'b1, X_M_pc2[14:7], X_M_t_pc2[14:0]} : {1'b1, X_M_pc1[14:7], X_M_t_pc1[14:0]};
    wire bimodal_br_taken = (btb_we2) ? X_M_br_taken2 : X_M_br_taken1;

    btb btb(
        /* input */
        .clk(sysclk), .pc1(F_D_pc2), .pc2(pc_intoF1), .waddr(btb_waddr), .we(btb_we), .wd(btb_wd),  
        /* output */
        .btb_hit1(btb_hit1), .pred_pc1(pred_pc1), .btb_hit2(btb_hit2), .pred_pc2(pred_pc2)
    );
    // pht pht(
    //     /* input */ 
    //     .clk(sysclk), .raddr(pc[6:2]), .waddr(D_X_pc[6:2]), .we(D_X_valid & D_X_is_br), .wd(br_taken),  
    //    /* output */
    //     .rd(pht_ret)
    // ); 
    bimodal bimodal(
        /* input */
        .clk(sysclk), .raddr1(F_D_pc2[6:2]), .raddr2(pc_intoF1[6:2]), .waddr(btb_waddr), .we(btb_we), .br_taken(bimodal_br_taken),  
        /* output */
        .ret1(pht_ret1), .ret2(pht_ret2)
    );
    // gshare gshare(
    //     /* input */
    //     .clk(sysclk), .raddr1(F_D_pc2[9:2]), .raddr2(pc_intoF1[9:2]), .waddr(btb_waddr), .we(btb_we), .br_taken(bimodal_br_taken),  
    //     /* output */
    //     .ret1(pht_ret1), .ret2(pht_ret2)
    // );
    

    // Fetch
    // 1. 次入れるpcを分岐予測を用いて算出
    // 2. 命令メモリからデータ(w_instruction)をfetchする準備を整える
    stage_F F(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .stall(stall), .w_miss(w_miss), .pc_in1(pc_intoF1), .pc_in2(pc_intoF2), .F_D_pc1(F_D_pc1), .F_D_pc2(F_D_pc2),
        .next_is_single(next_is_single),
        /* output */
        .w_pc1(pc1), .instruction1(w_instruction1), .w_pc2(pc2), .instruction2(w_instruction2)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            F_D_pc1    <= 8192*4;  F_D_pc2    <= -4 /*8192*4 - 4*/;  // <- F_D_pc2 + 4 がスタートになるように
            F_D_valid1 <= 0;       F_D_valid2 <= 0;
        end else if (!stall | w_miss) begin
            F_D_pc1    <= pc1;     F_D_pc2    <= pc2;
            F_D_valid1 <= 1'b1;    F_D_valid2 <= 1'b1;
        end
    end


    // Decode & Register Read
    // 1. クロック立ち上がりと同時に命令をfetchする
    // 2. fetchされた命令をdecodeする
    // 3. 2つの命令が同時実行可能か判定
    // 4. register read
    stage_D D(
        /* input */
        .instruction1(w_instruction1), .instruction2(w_instruction2),
        /* output */
        .rs1(rs1), .rs2(rs2), .rs3(rs3), .rs4(rs4), 
        .rd1(rd1), .rd2(rd2), .imm1(imm1), .imm2(imm2), .alucode1(alucode1), .alucode2(alucode2), 
        .aluop1_type1(aluop1_type1), .aluop2_type1(aluop2_type1), .aluop1_type2(aluop1_type2), .aluop2_type2(aluop2_type2),
        .reg_we1(reg_we1), .reg_we2(reg_we2), .is_load1(is_load1), .is_load2(is_load2),
        .is_store1(is_store1), .is_store2(is_store2), .is_br1(is_br1), .is_br2(is_br2),
        .is_jalr1(is_jalr1), .is_jalr2(is_jalr2), .is_halt1(is_halt1), .is_halt2(is_halt2), .next_is_single(next_is_single)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            D_X_pc1            <= 8192*4;  D_X_pc2            <= 8192*4 + 4;
            D_X_pc_added_imm1  <= 8192*4;  D_X_pc_added_imm2  <= 8192*4 + 4;
            D_X_pc_added_four1 <= 8192*4;  D_X_pc_added_four2 <= 8192*4 + 4;
            D_X_rs1            <= 0;       D_X_rs3            <= 0;
            D_X_rs2            <= 0;       D_X_rs4            <= 0;
            D_X_rd1            <= 0;       D_X_rd2            <= 0;
            D_X_imm1           <= 0;       D_X_imm2           <= 0;
            D_X_alucode1       <= 0;       D_X_alucode2       <= 0;
            D_X_aluop1_type1   <= 0;       D_X_aluop1_type2   <= 0;
            D_X_aluop2_type1   <= 0;       D_X_aluop2_type2   <= 0;
            D_X_reg_we1        <= 0;       D_X_reg_we2        <= 0;
            D_X_is_load1       <= 0;       D_X_is_load2       <= 0;
            D_X_is_store1      <= 0;       D_X_is_store2      <= 0;
            D_X_is_br1         <= 0;       D_X_is_br2         <= 0;
            D_X_is_jalr1       <= 0;       D_X_is_jalr2       <= 0;
            D_X_is_halt1       <= 0;       D_X_is_halt2       <= 0;
            D_X_valid1         <= 0;       D_X_valid2         <= 0;
            D_X_reg_data1      <= 0;       D_X_reg_data3      <= 0;
            D_X_reg_data2      <= 0;       D_X_reg_data4      <= 0;
        end else if (!stall | w_miss) begin
            D_X_pc1            <= F_D_pc1;               D_X_pc2            <= F_D_pc2;
            D_X_pc_added_imm1  <= F_D_pc1 + imm1;        D_X_pc_added_imm2  <= F_D_pc2 + imm2;
            D_X_pc_added_four1 <= F_D_pc1 + 4;           D_X_pc_added_four2 <= F_D_pc2 + 4;
            D_X_rs1            <= rs1;                   D_X_rs3            <= rs3;
            D_X_rs2            <= rs2;                   D_X_rs4            <= rs4;
            D_X_rd1            <= rd1;                   D_X_rd2            <= rd2;
            D_X_imm1           <= imm1;                  D_X_imm2           <= imm2;
            D_X_alucode1       <= alucode1;              D_X_alucode2       <= alucode2;
            D_X_aluop1_type1   <= aluop1_type1;          D_X_aluop1_type2   <= aluop1_type2;
            D_X_aluop2_type1   <= aluop2_type1;          D_X_aluop2_type2   <= aluop2_type2;
            D_X_reg_we1        <= reg_we1;               D_X_reg_we2        <= reg_we2;
            D_X_is_load1       <= is_load1;              D_X_is_load2       <= is_load2;
            D_X_is_store1      <= is_store1;             D_X_is_store2      <= is_store2;
            D_X_is_br1         <= is_br1;                D_X_is_br2         <= is_br2;
            D_X_is_jalr1       <= is_jalr1;              D_X_is_jalr2       <= is_jalr2;
            D_X_is_halt1       <= is_halt1;              D_X_is_halt2       <= is_halt2;
            D_X_valid1         <= !w_miss & F_D_valid1;  D_X_valid2         <= !w_miss & F_D_valid2 & !next_is_single;
            D_X_reg_data1 <= 
                (do_wb2 & (M_W_rd2==rs1)) ? wb_data2 : 
                (do_wb1 & (M_W_rd1==rs1)) ? wb_data1 : reg_data1;
            D_X_reg_data2 <= 
                (do_wb2 & (M_W_rd2==rs2)) ? wb_data2 : 
                (do_wb1 & (M_W_rd1==rs2)) ? wb_data1 : reg_data2; 
            D_X_reg_data3 <= 
                (do_wb2 & (M_W_rd2==rs3)) ? wb_data2 : 
                (do_wb1 & (M_W_rd1==rs3)) ? wb_data1 : reg_data3;
            D_X_reg_data4 <= 
                (do_wb2 & (M_W_rd2==rs4)) ? wb_data2 : 
                (do_wb1 & (M_W_rd1==rs4)) ? wb_data1 : reg_data4;
        end else if (/* !w_miss & stall & */do_wb) begin
            D_X_reg_data1 <= (do_wb2 & rs1_match_Wrd2) ? wb_data2 : (do_wb1 & rs1_match_Wrd1) ? wb_data1 : D_X_reg_data1;
            D_X_reg_data2 <= (do_wb2 & rs2_match_Wrd2) ? wb_data2 : (do_wb1 & rs2_match_Wrd1) ? wb_data1 : D_X_reg_data2;
            D_X_reg_data3 <= (do_wb2 & rs3_match_Wrd2) ? wb_data2 : (do_wb1 & rs3_match_Wrd1) ? wb_data1 : D_X_reg_data3;
            D_X_reg_data4 <= (do_wb2 & rs4_match_Wrd2) ? wb_data2 : (do_wb1 & rs4_match_Wrd1) ? wb_data1 : D_X_reg_data4;
        end
    end


    // Execution
    // 1. フォワーディングする、ロードユース発生時は1つバブルを挟む
    // 2. ALUに渡すデータを整える
    // 3. ALUによる計算
    // 4. t_pcの計算
    stage_X X1(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .alucode(D_X_alucode1), 
        .reg_data1(reg_data1_forward), .reg_data2(reg_data2_forward), .pc(D_X_pc1), .imm(D_X_imm1), 
        .pc_added_imm(D_X_pc_added_imm1), .pc_added_four(D_X_pc_added_four1),
        .aluop1_type(D_X_aluop1_type1), .aluop2_type(D_X_aluop2_type1), 
        .is_load(D_X_is_load1), .is_store(D_X_is_store1), .is_jalr(D_X_is_jalr1),
        .w_miss(w_miss), .wait_load(wait_load), .D_X_valid(D_X_valid1), .other_busy(busy2),
        /* output */
        .alu_result(alu_result1), .br_taken(br_taken1), .busy(busy1), .t_pc(t_pc1)
    );

    stage_X X2(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .alucode(D_X_alucode2), 
        .reg_data1(reg_data3_forward), .reg_data2(reg_data4_forward), .pc(D_X_pc2), .imm(D_X_imm2), 
        .pc_added_imm(D_X_pc_added_imm2), .pc_added_four(D_X_pc_added_four2),
        .aluop1_type(D_X_aluop1_type2), .aluop2_type(D_X_aluop2_type2), 
        .is_load(D_X_is_load2), .is_store(D_X_is_store2), .is_jalr(D_X_is_jalr2),
        .w_miss(w_miss), .wait_load(wait_load), .D_X_valid(D_X_valid2), .other_busy(busy1),
        /* output */
        .alu_result(alu_result2), .br_taken(br_taken2), .busy(busy2), .t_pc(t_pc2)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            X_M_pc1         <= 8192*4;   X_M_pc2         <= 8192*4;
            X_M_t_pc1       <= 8192*4;   X_M_t_pc2       <= 8192*4;
            X_M_is_br1      <= 0;        X_M_is_br2      <= 0;
            X_M_br_taken1   <= 0;        X_M_br_taken2   <= 0;
            X_M_write_data1 <= 0;        X_M_write_data2 <= 0;
            X_M_rd1         <= 0;        X_M_rd2         <= 0;
            X_M_alucode1    <= 0;        X_M_alucode2    <= 0;
            X_M_is_load1    <= 0;        X_M_is_load2    <= 0;
            X_M_is_store1   <= 0;        X_M_is_store2   <= 0;
            X_M_reg_we1     <= 0;        X_M_reg_we2     <= 0;
            X_M_alu_result1 <= 0;        X_M_alu_result2 <= 0;
            X_M_valid1      <= 0;        X_M_valid2      <= 0;
        end else if (!stall | w_miss) begin
            X_M_pc1         <= D_X_pc1;                X_M_pc2         <= D_X_pc2;
            X_M_t_pc1       <= t_pc1;                  X_M_t_pc2       <= t_pc2;
            X_M_is_br1      <= D_X_is_br1;             X_M_is_br2      <= D_X_is_br2;
            X_M_br_taken1   <= br_taken1;              X_M_br_taken2   <= br_taken2;
            X_M_write_data1 <= reg_data2_forward;      X_M_write_data2 <= reg_data4_forward;
            X_M_rd1         <= D_X_rd1;                X_M_rd2         <= D_X_rd2;
            X_M_alucode1    <= D_X_alucode1;           X_M_alucode2    <= D_X_alucode2;
            X_M_is_load1    <= D_X_is_load1;           X_M_is_load2    <= D_X_is_load2;
            X_M_is_store1   <= D_X_is_store1;          X_M_is_store2   <= D_X_is_store2;
            X_M_reg_we1     <= D_X_reg_we1;            X_M_reg_we2     <= D_X_reg_we2;
            X_M_alu_result1 <= alu_result1;            X_M_alu_result2 <= alu_result2;
            X_M_valid1      <= D_X_valid1 & !w_miss;   X_M_valid2      <= D_X_valid2 & !w_miss;
        end else /*if (stall)*/ begin
            X_M_valid1      <= 1'b0;
            X_M_valid2      <= 1'b0;
        end
    end

    wire w_M_W_valid2 = X_M_valid2 & !w_miss1;

    // Memory Access
    // 1. Exeステージで算出しておいたt_pcを用いて分岐予測の結果を算出、ミスならw_missを1に
    // 2. メモリからデータ(w_mem_data)をfetchする準備を整える
    stage_M M(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .valid1(X_M_valid1), .valid2(w_M_W_valid2),
        .is_store1(X_M_is_store1), .is_store2(X_M_is_store2), .addr1(X_M_alu_result1), .addr2(X_M_alu_result2),
        .write_data1(X_M_write_data1), .write_data2(X_M_write_data2), 
        .alucode1(X_M_alucode1), .alucode2(X_M_alucode2), .uart_OUT_data(uart_OUT_data), 
        /* output */
        .dm_r_data1(w_mem_data1), .dm_r_data2(w_mem_data2), 
        .byte_offset1(byte_offset1), .byte_offset2(byte_offset2),
        .is_hardware1(is_hardware1), .is_hardware2(is_hardware2),
        .uart_IN_data(uart_IN_data), .uart_we(uart_we), .uart_tx(uart_tx)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            M_W_alu_result1  <= 0;  M_W_alu_result2  <= 0;
            M_W_alucode1     <= 0;  M_W_alucode2     <= 0;
            M_W_rd1          <= 0;  M_W_rd2          <= 0;  
            M_W_reg_we1      <= 0;  M_W_reg_we2      <= 0;  
            M_W_byte_offset1 <= 0;  M_W_byte_offset2 <= 0;
            M_W_is_hardware1 <= 0;  M_W_is_hardware2 <= 0;
            M_W_valid1       <= 0;  M_W_valid2       <= 0;  
        end else begin
            M_W_alu_result1  <= X_M_alu_result1;  M_W_alu_result2  <= X_M_alu_result2;  
            M_W_alucode1     <= X_M_alucode1;     M_W_alucode2     <= X_M_alucode2; 
            M_W_rd1          <= X_M_rd1;          M_W_rd2          <= X_M_rd2;
            M_W_reg_we1      <= X_M_reg_we1;      M_W_reg_we2      <= X_M_reg_we2;
            M_W_byte_offset1 <= byte_offset1;     M_W_byte_offset2 <= byte_offset2;
            M_W_is_hardware1 <= is_hardware1;     M_W_is_hardware2 <= is_hardware2;
            M_W_valid1       <= X_M_valid1;       M_W_valid2       <= w_M_W_valid2;
        end
    end


    // Write back
    // 1. クロック立ち上がりと同時にメモリからデータをfetchする
    // 2. データ(wb_data)をレジスタに書き戻す準備を整える
    stage_W W1(
        /* input */
        .alu_result(M_W_alu_result1), .mem_data(w_mem_data1), .alucode(M_W_alucode1), .hc_OUT_data(hc_OUT_data),
        .byte_offset(M_W_byte_offset1), .is_hardware(M_W_is_hardware1),
        /* output */
        .wb_data(wb_data1)
    );

    stage_W W2(
        /* input */
        .alu_result(M_W_alu_result2), .mem_data(w_mem_data2), .alucode(M_W_alucode2), .hc_OUT_data(hc_OUT_data),
        .byte_offset(M_W_byte_offset2), .is_hardware(M_W_is_hardware2),
        /* output */
        .wb_data(wb_data2)
    );


    // レジスタファイルの内部定義
    register_file reg_file (
        .raddr1(rs1),
        .rdata1(reg_data1),
        .raddr2(rs2),
        .rdata2(reg_data2),
        .raddr3(rs3),
        .rdata3(reg_data3),
        .raddr4(rs4),
        .rdata4(reg_data4),
        .we1(do_wb1 & (!M_W_valid2 | M_W_rd1 != M_W_rd2)),
        .waddr1(M_W_rd1),
        .wdata1(wb_data1),
        .we2(do_wb2),
        .waddr2(M_W_rd2),
        .wdata2(wb_data2),
        .clk(sysclk)
    );


    hardware_counter hardware_counter0(
        .CLK_IP(sysclk),
        .RSTN_IP(cpu_resetn),
        .COUNTER_OP(hc_OUT_data)
    );
    uart uart0(
        .uart_tx(uart_OUT_data),
        .uart_wr_i(uart_we),
        .uart_dat_i(uart_IN_data),
        .sys_clk_i(sysclk),
        .sys_rstn_i(cpu_resetn)
    );
endmodule
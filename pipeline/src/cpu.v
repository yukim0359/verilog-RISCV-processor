`include "define.vh"

module cpu(
    input wire sysclk,                   // クロック信号
    input wire cpu_resetn,               // リセット信号
    output wire uart_tx
);

    // Stage Fからの信号
    wire [16:0] pc;
    wire [31:0] w_instruction;

    // Stage Dからの信号
    wire [4:0] rs1, rs2, rd;
    wire [31:0] imm;
    wire [5:0] alucode;
    wire [1:0] aluop1_type, aluop2_type;
    wire reg_we, is_load, is_store, is_br, is_jalr, is_halt;

    // Stage Xからの信号
    wire [31:0] alu_result;
    wire [16:0] t_pc;
    wire br_taken, busy;
    
    // Stage Mからの信号
    wire [31:0] w_mem_data;
    wire [4:0] byte_offset;
    wire is_hardware;
    
    // Stage Wからの信号
    wire [31:0] wb_data;

    // レジスタファイル
    wire [31:0] reg_data1, reg_data2;

    // Stage間パイプラインレジスタ定義
    reg [16:0] F_D_pc;
    reg F_D_valid;
    
    reg [31:0] D_X_imm, D_X_reg_data1, D_X_reg_data2;
    reg [16:0] D_X_pc, D_X_pc_added_imm, D_X_pc_added_4;
    reg [5:0] D_X_alucode;
    reg [4:0] D_X_rs1, D_X_rs2, D_X_rd;
    reg [1:0] D_X_aluop1_type, D_X_aluop2_type;
    reg D_X_reg_we, D_X_is_load, D_X_is_store, D_X_is_halt, D_X_is_br, D_X_is_jalr;
    reg D_X_valid;
    
    reg [31:0] X_M_alu_result, X_M_write_data;
    reg [16:0] X_M_pc, X_M_t_pc; 
    reg [5:0] X_M_alucode;
    reg [4:0] X_M_rd;
    reg X_M_reg_we, X_M_is_load, X_M_is_store;
    reg X_M_is_br, X_M_br_taken;  
    reg X_M_valid;
    
    reg [31:0] M_W_alu_result;
    reg [5:0] M_W_alucode;
    reg [4:0] M_W_rd, M_W_byte_offset;
    reg M_W_is_load, M_W_reg_we, M_W_is_hardware;
    reg M_W_valid;
    
    wire fwd1_XM, fwd1_MW, fwd2_XM, fwd2_MW;
    wire [31:0] reg_data1_forward, reg_data2_forward;
    
    /* HardwareCounter */
    wire [31:0] hc_OUT_data;
    
    /* uart */
    wire [7:0] uart_IN_data;
    wire uart_we;
    wire uart_OUT_data;
    
    //wire XM_rd_neq0 = (X_M_rd != 5'b0);
    //wire MW_rd_neq0 = (M_W_rd != 5'b0);
    
    // 先にあるステージのrdがrs1と一致するか
    wire rs1_match_XM = (X_M_rd == D_X_rs1) & X_M_reg_we;
    wire rs1_match_MW = (M_W_rd == D_X_rs1) & M_W_reg_we;
    wire rs2_match_XM = (X_M_rd == D_X_rs2) & X_M_reg_we;
    wire rs2_match_MW = (M_W_rd == D_X_rs2) & M_W_reg_we;

    // Load-Use
    wire wait_load = D_X_valid & X_M_valid & X_M_is_load & (rs1_match_XM | rs2_match_XM);
    wire stall = wait_load | busy;

    // そのステージでwrite backを行うか
    wire do_wb = M_W_valid & M_W_reg_we;


    // 分岐予測
    wire [16:0] pred_pc;
    wire btb_hit, pht_ret;
    wire pred_br_taken = btb_hit & pht_ret;
    wire w_miss = X_M_valid & D_X_valid & (D_X_pc != X_M_t_pc);
    wire [16:0] pc_in = (w_miss) ? X_M_t_pc : (pred_br_taken) ? pred_pc : F_D_pc + 4;
    wire [27:0] btb_wd = {1'b1, X_M_pc[16:7], X_M_t_pc[16:0]};

    btb btb(
        /* input */
        .clk(sysclk), .pc(F_D_pc), .waddr(X_M_pc[6:2]), .we(X_M_valid & X_M_is_br), .wd(btb_wd),  
        /* output */
        .btb_hit(btb_hit), .pred_pc(pred_pc)
    ); 
    //pht pht(
    //    /* input */ 
    //    .clk(sysclk), .raddr(pc[6:2]), .waddr(D_X_pc[6:2]), .we(D_X_valid & D_X_is_br), .wd(br_taken),  
    //   /* output */
    //    .rd(pht_ret)
    //); 
    bimodal bimodal(
        /* input */
        .clk(sysclk), .raddr(F_D_pc[6:2]), .waddr(X_M_pc[6:2]), .we(X_M_valid & X_M_is_br), .br_taken(br_taken),  
        /* output */
        .ret(pht_ret)
    );
    //gshare gshare(
    //    /* input */
    //    .clk(sysclk), .raddr(pc[6:2]), .waddr(D_X_pc[6:2]), .we(D_X_valid & D_X_is_br), .br_taken(br_taken),  
    //    /* output */
    //    .ret(pht_ret)
    //);


    // Fetch
    // 1. pcを更新する
    // 2. 命令メモリからデータ(w_instruction)をfetchする準備を整える
    stage_F F(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .stall(stall), .w_miss(w_miss), .pc_in(pc_in),
        /* output */
        .w_pc(pc), .instruction(w_instruction)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            F_D_pc    <= 8192*4-4;
            F_D_valid <= 0;
        end else if (!stall | w_miss) begin
            F_D_pc    <= pc;
            F_D_valid <= 1;
        end
    end


    // Decode & Register Read
    // 1. クロック立ち上がりと同時に命令をfetchする
    // 2. fetchされた命令をdecodeする
    // 3. register read
    stage_D D(
        /* input */
        .instruction(w_instruction), 
        /* output */
        .rs1(rs1), .rs2(rs2), // この2つはレジスタファイルにつながっているwire
        .rd(rd), .imm(imm), .alucode(alucode), .aluop1_type(aluop1_type), .aluop2_type(aluop2_type), .reg_we(reg_we),
        .is_load(is_load), .is_store(is_store), .is_br(is_br), .is_jalr(is_jalr), .is_halt(is_halt)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            D_X_pc           <= 8192*4;
            D_X_pc_added_imm <= 8192*4;
            D_X_pc_added_4   <= 8192*4;
            D_X_rs1          <= 0;
            D_X_rs2          <= 0;
            D_X_rd           <= 0;
            D_X_imm          <= 0;
            D_X_alucode      <= 0;
            D_X_aluop1_type  <= 0;
            D_X_aluop2_type  <= 0;
            D_X_reg_data1    <= 0;
            D_X_reg_data2    <= 0;
            D_X_reg_we       <= 0;
            D_X_is_load      <= 0;
            D_X_is_store     <= 0;
            D_X_is_br        <= 0;
            D_X_is_jalr      <= 0;
            D_X_is_halt      <= 0;
            D_X_valid        <= 0;
        end else if(!stall | w_miss) begin
            D_X_pc           <= F_D_pc;
            D_X_pc_added_imm <= F_D_pc + imm;
            D_X_pc_added_4   <= F_D_pc + 4;
            D_X_rs1          <= rs1;
            D_X_rs2          <= rs2;
            D_X_rd           <= rd;
            D_X_imm          <= imm;
            D_X_alucode      <= alucode;
            D_X_aluop1_type  <= aluop1_type;
            D_X_aluop2_type  <= aluop2_type;
            D_X_reg_data1    <= (do_wb & (M_W_rd==rs1)) ? wb_data : reg_data1;
            D_X_reg_data2    <= (do_wb & (M_W_rd==rs2)) ? wb_data : reg_data2;            
            D_X_reg_we       <= reg_we;
            D_X_is_load      <= is_load;
            D_X_is_store     <= is_store;
            D_X_is_br        <= is_br;
            D_X_is_jalr      <= is_jalr;
            D_X_is_halt      <= is_halt;
            D_X_valid        <= !w_miss & F_D_valid;
        end else if (do_wb) begin
            if(rs1_match_MW) D_X_reg_data1 <= wb_data;
            if(rs2_match_MW) D_X_reg_data2 <= wb_data;
        end
    end

    // forwardingの判定
    wire tmp_XM = X_M_valid & X_M_reg_we & !X_M_is_load;
    wire tmp_MW = M_W_valid & M_W_reg_we;
    assign fwd1_XM = rs1_match_XM & tmp_XM;
    assign fwd1_MW = rs1_match_MW & tmp_MW;
    assign fwd2_XM = rs2_match_XM & tmp_XM;
    assign fwd2_MW = rs2_match_MW & tmp_MW;

    assign reg_data1_forward = (fwd1_XM) ? X_M_alu_result : (fwd1_MW) ? wb_data : D_X_reg_data1;
    assign reg_data2_forward = (fwd2_XM) ? X_M_alu_result : (fwd2_MW) ? wb_data : D_X_reg_data2;

    // Execution
    // 1. ALUに渡すデータを整える
    // 2. ALUによる計算
    stage_X X(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .alucode(D_X_alucode), 
        .reg_data1(reg_data1_forward), .reg_data2(reg_data2_forward), .pc(D_X_pc), .imm(D_X_imm), .pc_added_imm(D_X_pc_added_imm), .pc_added_4(D_X_pc_added_4),
        .aluop1_type(D_X_aluop1_type), .aluop2_type(D_X_aluop2_type), 
        .is_load(D_X_is_load), .is_store(D_X_is_store), .is_jalr(D_X_is_jalr),
        .w_miss(w_miss), .wait_load(wait_load), .D_X_valid(D_X_valid),
        /* output */
        .alu_result(alu_result), .br_taken(br_taken), .busy(busy), .t_pc(t_pc)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            X_M_pc         <= 8192*4;   
            X_M_t_pc       <= 8192*4;     
            X_M_is_br      <= 0;
            X_M_br_taken   <= 0; 
            X_M_write_data <= 0;
            X_M_rd         <= 0;
            X_M_alucode    <= 0;
            X_M_is_load    <= 0;
            X_M_is_store   <= 0;
            X_M_reg_we     <= 0;
            X_M_alu_result <= 0;
            X_M_valid      <= 0;
        end else if (!stall | w_miss)  begin
            X_M_pc         <= D_X_pc;   
            X_M_t_pc       <= t_pc;     
            X_M_is_br      <= D_X_is_br;
            X_M_br_taken   <= br_taken; 
            X_M_write_data <= reg_data2_forward;
            X_M_rd         <= D_X_rd;
            X_M_alucode    <= D_X_alucode;
            X_M_is_load    <= D_X_is_load;
            X_M_is_store   <= D_X_is_store;
            X_M_reg_we     <= D_X_reg_we;
            X_M_alu_result <= alu_result;
            X_M_valid      <= D_X_valid & !w_miss;
        end else if (stall) begin 
            X_M_valid      <= 1'b0;
        end
    end


    // Memory Access
    // 1. メモリからデータ(w_mem_data)をfetchする準備を整える
    stage_M M(
        /* input */
        .clk(sysclk), .reset(cpu_resetn), .valid(X_M_valid), .is_store(X_M_is_store),
        .addr(X_M_alu_result), .write_data(X_M_write_data), 
        .alucode(X_M_alucode), .uart_OUT_data(uart_OUT_data), 
        /* output */
        .dm_r_data(w_mem_data), .byte_offset(byte_offset),
        .is_hardware(is_hardware), .uart_IN_data(uart_IN_data), .uart_we(uart_we), .uart_tx(uart_tx)
    );

    always @(posedge sysclk or negedge cpu_resetn) begin
        if (!cpu_resetn) begin
            M_W_alu_result  <= 0;
            M_W_alucode     <= 0;
            M_W_is_load     <= 0;
            M_W_rd          <= 0;
            M_W_reg_we      <= 0;
            M_W_valid       <= 0;
            M_W_byte_offset <= 0;
            M_W_is_hardware <= 0;
        end else begin
            M_W_alu_result  <= X_M_alu_result;
            M_W_alucode     <= X_M_alucode;
            M_W_is_load     <= X_M_is_load;
            M_W_rd          <= X_M_rd;
            M_W_reg_we      <= X_M_reg_we;
            M_W_valid       <= X_M_valid;
            M_W_byte_offset <= byte_offset;
            M_W_is_hardware <= is_hardware;
        end
    end


    // Write back
    // 1. クロック立ち上がりと同時にメモリからデータをfetchする
    // 2. データ(wb_data)をレジスタに書き戻す準備を整える
    stage_W W(
        /* input */
        .alu_result(M_W_alu_result),
        .mem_data(w_mem_data), .is_load(M_W_is_load), .alucode(M_W_alucode), .hc_OUT_data(hc_OUT_data),
        .byte_offset(M_W_byte_offset), .is_hardware(M_W_is_hardware),
        /* output */
        .wb_data(wb_data)
    );


    // レジスタファイルの内部定義
    register_file reg_file (
        .clk(sysclk),
        .we(do_wb),
        .r_addr1(rs1),
        .r_addr2(rs2),
        .w_addr(M_W_rd),
        .w_data(wb_data),
        .r_data1(reg_data1),
        .r_data2(reg_data2)
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
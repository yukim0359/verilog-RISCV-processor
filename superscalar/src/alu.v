`include "define.vh"

module alu(
    input wire clk,
    input wire reset,
    input wire valid,
    input wire [5:0] alucode,
    input wire [31:0] reg_data1, reg_data2,
    input wire [31:0] op1, op2,
    input wire is_load,
    input wire is_store,
    input wire other_busy,
    output wire [31:0] alu_result,
    output wire busy
);

    // ALU操作の種類に対応する信号
    wire is_add   = (alucode == `ALU_ADD);
    wire is_sub   = (alucode == `ALU_SUB);
    wire is_slt   = (alucode == `ALU_SLT);
    wire is_sltu  = (alucode == `ALU_SLTU);
    wire is_xor   = (alucode == `ALU_XOR);
    wire is_or    = (alucode == `ALU_OR);
    wire is_and   = (alucode == `ALU_AND);
    wire is_sll   = (alucode == `ALU_SLL);
    wire is_srl   = (alucode == `ALU_SRL);
    wire is_sra   = (alucode == `ALU_SRA);
    wire is_jal   = (alucode == `ALU_JAL);
    wire is_jalr  = (alucode == `ALU_JALR);

    wire is_mul    = (alucode == `ALU_MUL);
    wire is_mulh   = (alucode == `ALU_MULH);
    wire is_mulhsu = (alucode == `ALU_MULHSU);
    wire is_mulhu  = (alucode == `ALU_MULHU);
    wire is_div    = (alucode == `ALU_DIV);
    wire is_divu   = (alucode == `ALU_DIVU);
    wire is_rem    = (alucode == `ALU_REM);
    wire is_remu   = (alucode == `ALU_REMU);

    // LUI命令
    wire is_lui   = (alucode == `ALU_LUI);

    // 32bit加算器の定義
    function [31:0] adder_32bit;
        input [31:0] a;  // 加算の第1オペランド
        input [31:0] b;  // 加算の第2オペランド
        begin
            adder_32bit = a + b;  // 加算結果
        end
    endfunction
    
    // 加算器の入力を制御するマルチプレクサ
    wire [31:0] adder_input1, adder_input2;
    assign adder_input1 = (is_jal | is_jalr) ? 32'd4 : op1;
    assign adder_input2 = (is_sub) ? ~op2 + 1 : op2;
    
    // 乗算・除算のbusyの定義
    wire div_exception1 = (reg_data2==32'h0000_0000);
    wire div_exception2 = (reg_data1==32'h8000_0000) & (reg_data2==32'hffff_ffff);
    reg [8:0] mul_state;
    reg [5:0] div_state;

    wire mul_busy = valid & (is_mul | is_mulh | is_mulhsu | is_mulhu) & (!mul_state[8]);
    // wire div_busy = valid & (is_div | is_divu | is_rem | is_remu) & !div_exception1 & !div_exception2 & !(div_state[5] & div_state[4]);
    wire div_busy = valid & (is_div | is_divu | is_rem | is_remu) & !div_exception1 & !div_exception2 & (div_state != 6'd63);

    assign busy = mul_busy | div_busy;

    // 乗算器
    function [63:0] calc_partial_product;
        input [31:0] multiplicand;   // 乗算される数
        input multiplier_bit;        // 乗算器の現在のビット
        input [4:0] bit_position;    // 現在のビット位置
        begin
            calc_partial_product = (multiplier_bit) ? {32'b0, multiplicand} << bit_position : 64'b0;
        end
    endfunction

    function [31:0] mul_postprocess;
        input [63:0] product_64bit;  // 計算された積
        input mul_negate;            // 結果を符号反転するかどうか
        input [5:0] shift_amount;    // シフト量
        begin
            mul_postprocess = ((mul_negate) ? ~product_64bit + 1 : product_64bit) >> shift_amount;
            // mul_postprocess = (((mul_negate) ? ~product_64bit : product_64bit) + ((mul_negate) ? 1 : 0)) >> shift_amount;
        end
    endfunction

    reg [63:0] mul_reg1, mul_reg2, mul_reg3, mul_reg4, mul_reg5, mul_reg6, mul_reg7, mul_reg8;
    reg [31:0] mul_op1, mul_op2;
    reg mul_negate;

    wire [5:0] mul_final_shift = (is_mul) ? 0 : 6'd32;

    wire [4:0] shift1 = (mul_state[1]) ? 5'd0 : (mul_state[2]) ? 5'd8  : (mul_state[3]) ? 5'd16 : (mul_state[4]) ? 5'd24 : 5'd0;
    wire [4:0] shift2 = (mul_state[1]) ? 5'd1 : (mul_state[2]) ? 5'd9  : (mul_state[3]) ? 5'd17 : (mul_state[4]) ? 5'd25 : 5'd0;
    wire [4:0] shift3 = (mul_state[1]) ? 5'd2 : (mul_state[2]) ? 5'd10 : (mul_state[3]) ? 5'd18 : (mul_state[4]) ? 5'd26 : 5'd0;
    wire [4:0] shift4 = (mul_state[1]) ? 5'd3 : (mul_state[2]) ? 5'd11 : (mul_state[3]) ? 5'd19 : (mul_state[4]) ? 5'd27 : 5'd0;
    wire [4:0] shift5 = (mul_state[1]) ? 5'd4 : (mul_state[2]) ? 5'd12 : (mul_state[3]) ? 5'd20 : (mul_state[4]) ? 5'd28 : 5'd0;
    wire [4:0] shift6 = (mul_state[1]) ? 5'd5 : (mul_state[2]) ? 5'd13 : (mul_state[3]) ? 5'd21 : (mul_state[4]) ? 5'd29 : 5'd0;
    wire [4:0] shift7 = (mul_state[1]) ? 5'd6 : (mul_state[2]) ? 5'd14 : (mul_state[3]) ? 5'd22 : (mul_state[4]) ? 5'd30 : 5'd0;
    wire [4:0] shift8 = (mul_state[1]) ? 5'd7 : (mul_state[2]) ? 5'd15 : (mul_state[3]) ? 5'd23 : (mul_state[4]) ? 5'd31 : 5'd0;

    wire [63:0] adder64_input1_1, adder64_input1_2,  adder64_input2_1, adder64_input2_2,
                adder64_input3_1, adder64_input3_2,  adder64_input4_1, adder64_input4_2,
                adder64_input5_1, adder64_input5_2,  adder64_input6_1, adder64_input6_2,
                adder64_input7_1, adder64_input7_2,  adder64_input8_1, adder64_input8_2;

    wire is_calculating_partial_product = |mul_state[4:1];  // mul_state[1] | mul_state[2] | mul_state[3] | mul_state[4];
    assign adder64_input1_1 = mul_reg1;
    assign adder64_input1_2 = (is_calculating_partial_product) ? calc_partial_product(mul_op1, mul_op2[shift1], shift1) : mul_reg2;
    assign adder64_input2_1 = (is_calculating_partial_product) ? mul_reg2 : mul_reg3;
    assign adder64_input2_2 = (is_calculating_partial_product) ? calc_partial_product(mul_op1, mul_op2[shift2], shift2) : mul_reg4;
    assign adder64_input3_1 = (is_calculating_partial_product) ? mul_reg3 : mul_reg5;
    assign adder64_input3_2 = (is_calculating_partial_product) ? calc_partial_product(mul_op1, mul_op2[shift3], shift3) : mul_reg6;
    assign adder64_input4_1 = (is_calculating_partial_product) ? mul_reg4 : mul_reg7;
    assign adder64_input4_2 = (is_calculating_partial_product) ? calc_partial_product(mul_op1, mul_op2[shift4], shift4) : mul_reg8;
    assign adder64_input5_1 = mul_reg5;
    assign adder64_input5_2 = calc_partial_product(mul_op1, mul_op2[shift5], shift5);
    assign adder64_input6_1 = mul_reg6;
    assign adder64_input6_2 = calc_partial_product(mul_op1, mul_op2[shift6], shift6);
    assign adder64_input7_1 = mul_reg7;
    assign adder64_input7_2 = calc_partial_product(mul_op1, mul_op2[shift7], shift7);
    assign adder64_input8_1 = mul_reg8;
    assign adder64_input8_2 = calc_partial_product(mul_op1, mul_op2[shift8], shift8);

    /*1,2,3,4 : begin
        mul_reg1 <= mul_reg1 + calc_partial_product(mul_op1, mul_op2[shift1], shift1);
        mul_reg2 <= mul_reg2 + calc_partial_product(mul_op1, mul_op2[shift2], shift2);
        mul_reg3 <= mul_reg3 + calc_partial_product(mul_op1, mul_op2[shift3], shift3);
        mul_reg4 <= mul_reg4 + calc_partial_product(mul_op1, mul_op2[shift4], shift4);
        mul_reg5 <= mul_reg5 + calc_partial_product(mul_op1, mul_op2[shift5], shift5);
        mul_reg6 <= mul_reg6 + calc_partial_product(mul_op1, mul_op2[shift6], shift6);
        mul_reg7 <= mul_reg7 + calc_partial_product(mul_op1, mul_op2[shift7], shift7);
        mul_reg8 <= mul_reg8 + calc_partial_product(mul_op1, mul_op2[shift8], shift8);
        mul_state <= mul_state + 1;
    end
    5 : begin // 部分積をまとめる
        mul_reg1 <= mul_reg1 + mul_reg2;
        mul_reg2 <= mul_reg3 + mul_reg4;
        mul_reg3 <= mul_reg5 + mul_reg6;
        mul_reg4 <= mul_reg7 + mul_reg8;
        mul_state <= mul_state + 1;
    end
    6 : begin
        mul_reg1 <= mul_reg1 + mul_reg2;
        mul_reg2 <= mul_reg3 + mul_reg4;
        mul_state <= mul_state + 1;
    end
    7 : begin
        mul_reg1 <= mul_reg1 + mul_reg2;
        mul_state <= mul_state + 1;
    end
    8 : begin
        mul_state <= 0;
    end*/


    // 除算器
    /*function [31:0] calc_partial_division;
        input [31:0] dividend;         // 被除数
        input [31:0] divisor;          // 除数
        input [4:0] shift_amount;      // シフト量
        begin
            calc_partial_division = (dividend >> shift_amount) - divisor;
        end
    endfunction*/

    function [63:0] calc_partial_division;
        input [31:0] dividend;         // 被除数
        input [31:0] divisor;          // 除数
        input [4:0] shift_amount;      // シフト量
        begin
            calc_partial_division = {32'b0, dividend} - ({32'b0, divisor} << shift_amount);
        end
    endfunction

    function determine_div_bit;
        input [63:0] calc_partial_division;  // 部分剰余
        begin
            determine_div_bit = !calc_partial_division[63];
        end
    endfunction

    function [31:0] div_postprocess;
        input [31:0] quotient;  // 商の計算結果
        input div_negate;
        begin
            div_postprocess = (div_negate) ? ~quotient + 1 : quotient;
        end
    endfunction

    function [31:0] rem_postprocess;
        input [31:0] remainder;  // 余りの計算結果
        input rem_negate;
        begin
            rem_postprocess = (rem_negate) ? ~remainder + 1 : remainder;
        end
    endfunction

    reg [31:0] div_quotient;
    reg [31:0] div_op1, div_op2;
    reg div_negate, rem_negate;

    wire [63:0] partial_division = calc_partial_division(div_op1, div_op2, div_state);
    wire division_bit = determine_div_bit(partial_division);

    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            mul_op1      <= 32'b0;
            mul_op2      <= 32'b0;
            mul_state    <= 9'b000000001;
            mul_negate   <= 1'b0;
            mul_reg1     <= 64'b0;
            mul_reg2     <= 64'b0;
            mul_reg3     <= 64'b0;
            mul_reg4     <= 64'b0;
            mul_reg5     <= 64'b0;
            mul_reg6     <= 64'b0;
            mul_reg7     <= 64'b0;
            mul_reg8     <= 64'b0;
            div_quotient <= 32'b0;
            div_op1      <= 32'b0;
            div_op2      <= 32'b0;
            div_state    <= 6'd32;
            div_negate   <= 0;
            rem_negate   <= 0;
        end else if (valid & (is_mulh | is_mulhsu | is_mul | is_mulhu)) begin
            if(mul_state[0]) begin
                mul_reg1 <= 64'b0;
                mul_reg2 <= 64'b0;
                mul_reg3 <= 64'b0;
                mul_reg4 <= 64'b0;
                mul_reg5 <= 64'b0;
                mul_reg6 <= 64'b0;
                mul_reg7 <= 64'b0;
                mul_reg8 <= 64'b0;
                mul_state <= 9'b000000010;
                if(is_mulh) begin
                    mul_op1    <= (reg_data1[31]) ? ~reg_data1 + 1 : reg_data1;
                    mul_op2    <= (reg_data2[31]) ? ~reg_data2 + 1 : reg_data2;
                    mul_negate <= reg_data1[31] ^ reg_data2[31];
                end else if(is_mulhsu) begin
                    mul_op1    <= (reg_data1[31]) ? ~reg_data1 + 1 : reg_data1;
                    mul_op2    <= reg_data2;
                    mul_negate <= reg_data1[31];
                end else if(is_mul || is_mulhu) begin
                    mul_op1    <= reg_data1;
                    mul_op2    <= reg_data2;
                    mul_negate <= 0;
                end
            end else if (mul_state[8]) begin
                mul_state <= (other_busy) ? 9'b100000000 : 9'b000000001;
                // mul_state[8] <= (other_busy) ? 1 : 0;
                // mul_state[0] <= (other_busy) ? 0 : 1;
            end else begin
                mul_reg1 <= adder64_input1_1 + adder64_input1_2;
                mul_reg2 <= adder64_input2_1 + adder64_input2_2;
                mul_reg3 <= adder64_input3_1 + adder64_input3_2;
                mul_reg4 <= adder64_input4_1 + adder64_input4_2;
                mul_reg5 <= adder64_input5_1 + adder64_input5_2;
                mul_reg6 <= adder64_input6_1 + adder64_input6_2;
                mul_reg7 <= adder64_input7_1 + adder64_input7_2;
                mul_reg8 <= adder64_input8_1 + adder64_input8_2;
                mul_state <= mul_state << 1;
            end
        end else if (valid & (is_div | is_divu | is_rem | is_remu)) begin
            case(div_state)
                32: begin // signedなら正の数に直す
                    if((is_div | is_rem) & !div_exception1 & !div_exception2) begin
                        div_op1      <= (reg_data1[31]) ? ~reg_data1 + 1 : reg_data1;
                        div_op2      <= (reg_data2[31]) ? ~reg_data2 + 1 : reg_data2;
                        div_negate   <= reg_data1[31] ^ reg_data2[31];
                        rem_negate   <= reg_data1[31];
                        div_quotient <= 32'b0;
                        div_state    <= 6'd31;
                        // div_state    <= 6'd33;
                    end else if((is_divu | is_remu) & !div_exception1) begin
                        div_op1      <= reg_data1;
                        div_op2      <= reg_data2;
                        div_negate   <= 0;
                        rem_negate   <= 0;
                        div_quotient <= 32'b0;
                        div_state    <= 6'd31;
                        // div_state    <= 6'd33;
                    end
                end
                /*33: begin // 最初のシフト量を決定
                    if(div_op2[31:24] != 8'b0) div_state <= 6'd7;
                    else if(div_op2[23:16] != 8'b0) div_state <= 6'd15;
                    else if(div_op2[15:8] != 8'b0) div_state <= 6'd23;
                    else div_state <= 6'd31;
                end*/
                63: begin
                    div_state <= 32;
                    // div_state <= (other_busy) ? 63 : 32;
                end
                default : begin
                    // if(division_bit) div_op1 <= div_op1 - (div_op2 << div_state);
                    // if(division_bit) div_op1[31 : div_state] <= partial_division[31-div_state : 0];
                    if(division_bit) div_op1 <= partial_division[31:0];
                    div_quotient[div_state] <= division_bit;
                    div_state <= div_state - 1;
                end
            endcase
        end
    end


    assign alu_result = 
            (is_add | is_sub | is_load | is_store | is_jal | is_jalr) ? adder_32bit(adder_input1, adder_input2) :
            (is_slt)                                                  ? (($signed(op1) < $signed(op2)) ? 32'b1 : 32'b0) : 
            (is_sltu)                                                 ? ((op1 < op2) ? 32'b1 : 32'b0) : 
            (is_xor)                                                  ? (op1 ^ op2):
            (is_or)                                                   ? (op1 | op2):
            (is_and)                                                  ? (op1 & op2):
            (is_sll)                                                  ? (op1 << op2[4:0]):
            (is_srl)                                                  ? (op1 >> op2[4:0]): 
            (is_sra)                                                  ? ($signed({{32{op1[31]}}, op1}) >>> op2[4:0]) :
            (is_lui)                                                  ? op2 :
            (is_mul | is_mulh | is_mulhsu | is_mulhu)                 ? mul_postprocess(mul_reg1, mul_negate, mul_final_shift) :
            ((is_div | is_divu) & div_exception1)                     ? 32'hffff_ffff : 
            (is_div & div_exception2)                                 ? 32'h8000_0000 : 
            (is_div | is_divu)                                        ? div_postprocess(div_quotient, div_negate) :
            ((is_rem | is_remu) & div_exception1)                     ? op1:
            (is_rem & div_exception2)                                 ? 0 : 
            (is_rem | is_remu)                                        ? rem_postprocess(div_op1, rem_negate) :
                                                                        32'b0;

endmodule
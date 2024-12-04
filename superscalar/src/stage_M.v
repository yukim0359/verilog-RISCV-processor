module stage_M(
    input wire clk,
    input wire reset,
    input wire valid1, valid2,
    input wire is_store1, is_store2,
    input wire [31:0] addr1, addr2,
    input wire [31:0] write_data1, write_data2,
    input wire [5:0] alucode1, alucode2,
    input wire uart_OUT_data,
    output wire [31:0] dm_r_data1, dm_r_data2,
    output wire [4:0] byte_offset1, byte_offset2, 
    output wire is_hardware1, is_hardware2,
    output wire [7:0] uart_IN_data,
    output wire uart_we,
    output wire uart_tx
);

    assign byte_offset1 = addr1[1:0] * 8;
    assign byte_offset2 = addr2[1:0] * 8;

    wire [3:0] selected_store_valids;
    assign selected_store_valids =
        (is_store1) ? {4{valid1}} : 
        (is_store2) ? {4{valid2}} : 4'b0;

    wire [14:0] dm_r_addr1 = addr1[16:2];
    wire [14:0] dm_r_addr2 = addr2[16:2];

    wire [3:0] dm_we;
    wire [31:0] dm_w_data;

    wire [31:0] selected_store_addr = (is_store1) ? addr1 : addr2;
    wire [31:0] selected_store_data = (is_store1) ? write_data1 : write_data2;
    wire [4:0] store_byte_offset = (is_store1) ? byte_offset1 : byte_offset2;

    wire is_sb    = (alucode1 == `ALU_SB) | (alucode2 == `ALU_SB);
    wire is_sh    = (alucode1 == `ALU_SH) | (alucode2 == `ALU_SH);
    wire is_sw    = (alucode1 == `ALU_SW) | (alucode2 == `ALU_SW);
    wire is_uart  = (is_store1 & (addr1 == `UART_ADDR)) | (is_store2 & (addr2 == `UART_ADDR));

    assign dm_we = 
        (is_sb & !is_uart) ? (4'b1 << selected_store_addr[1:0]) : 
        (is_sh & !is_uart) ? (4'b1 << selected_store_addr[1:0]) | (4'b1 << (selected_store_addr[1:0] + 1)) : 
        (is_sw & !is_uart) ? 4'b1111 : 4'b0;

    assign dm_w_data =
        (is_sb & !is_uart) ? (selected_store_data[7:0] << store_byte_offset) : 
        (is_sh & !is_uart) ? (selected_store_data[15:0] << store_byte_offset) : 
        (is_sw & !is_uart) ? selected_store_data : 32'b0;

    data_memory data_mem(
        .clk(clk),
        .we(dm_we & selected_store_valids),
        .r_addr1(dm_r_addr1),
        .r_data1(dm_r_data1),
        .r_addr2(dm_r_addr2),
        .r_data2(dm_r_data2),
        .w_addr(selected_store_addr[16:2]),
        .w_data(dm_w_data)
    );

    // Memory Accessステージに以下のような記述を追加
    assign uart_IN_data = selected_store_data[7:0];  // ストアするデータをモジュールへ入力
    assign uart_we = (selected_store_valids[0] & is_uart);
    // assign uart_we = (valid && (addr == `UART_ADDR) && (is_store == `ENABLE)) ? 1'b1 : 1'b0;  // シリアル通信用アドレスへのストア命令実行時に送信開始信号をアサート
    assign uart_tx = uart_OUT_data;  // シリアル通信モジュールの出力はFPGA外部へと出力

    assign is_hardware1 = (addr1 == `HARDWARE_COUNTER_ADDR);
    assign is_hardware2 = (addr2 == `HARDWARE_COUNTER_ADDR);
    
endmodule
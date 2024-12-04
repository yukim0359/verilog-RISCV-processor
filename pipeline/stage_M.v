module stage_M(
    input wire clk,
    input wire reset,
    input wire valid,
    input wire is_store,
    input wire [31:0] addr,
    input wire [31:0] write_data,
    input wire [5:0] alucode,
    input wire uart_OUT_data,
    output wire [31:0] dm_r_data,
    output wire [4:0] byte_offset,
    output wire is_hardware,
    output wire [7:0] uart_IN_data,
    output wire uart_we,
    output wire uart_tx
);

    wire [3:0] valids;
    assign valids = {valid, valid, valid, valid}; 
   
    wire [14:0] dm_addr;
    assign dm_addr = addr[16:2];
    
    wire is_sb    = (alucode == `ALU_SB);
    wire is_sh    = (alucode == `ALU_SH);
    wire is_sw    = (alucode == `ALU_SW);
    wire is_uart  = is_store & (addr == `UART_ADDR);

    wire [3:0] dm_we;
    wire [31:0] dm_w_data;
    
    assign byte_offset = addr[1:0] * 8;
    
    assign dm_we = 
        (is_sb & !is_uart) ? (4'b1 << addr[1:0]) : 
        (is_sh & !is_uart) ? (4'b1 << addr[1:0]) | (4'b1 << (addr[1:0] + 1)) : 
        (is_sw & !is_uart) ? 4'b1111 : 4'b0;

    assign dm_w_data =
        (is_sb & !is_uart) ? (write_data[7:0] << byte_offset) : 
        (is_sh & !is_uart) ? (write_data[15:0] << byte_offset) : 
        (is_sw & !is_uart) ? write_data : 32'b0;

    data_memory data_mem(
        .clk(clk),
        .we(dm_we & valids),
        .r_addr(dm_addr),
        .r_data(dm_r_data),
        .w_addr(dm_addr),
        .w_data(dm_w_data)
    );

     // Memory Accessステージに以下のような記述を追加
    assign uart_IN_data = write_data[7:0];  // ストアするデータをモジュールへ入力
    assign uart_we = (valid & is_uart);
    assign uart_tx = uart_OUT_data;  // シリアル通信モジュールの出力はFPGA外部へと出力
   
    assign is_hardware = (addr == `HARDWARE_COUNTER_ADDR);
    
endmodule
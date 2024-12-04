module data_memory(clk, we, r_addr, r_data, w_addr, w_data);
    input clk;
    input [3:0] we; // 書き込むバイトは1, 書き込まないでそのままにするバイトは0を指定
    input [14:0] r_addr, w_addr;
    input [31:0] w_data;
    output reg [31:0] r_data;
    
    reg [31:0] data_mem [0:32767];
    
    // 初期化 (テスト用にデータをプリロードする場合)
    initial begin
        // $readmemh("/home/denjo/b3exp/benchmarks/Coremark/data.hex", data_mem);
        $readmemh("/home/denjo/b3exp/benchmarks/Coremark_for_Synthesis/data.hex", data_mem);
    end

    always @(posedge clk) begin
        if(we[0]) data_mem[w_addr][ 7: 0] <= w_data[ 7: 0];
        if(we[1]) data_mem[w_addr][15: 8] <= w_data[15: 8];
        if(we[2]) data_mem[w_addr][23:16] <= w_data[23:16];
        if(we[3]) data_mem[w_addr][31:24] <= w_data[31:24];
        r_data <= data_mem[r_addr];
    end
endmodule
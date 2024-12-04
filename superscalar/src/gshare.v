module gshare(
    input wire clk, we,
    input wire [7:0] waddr, raddr1, raddr2,
    input wire br_taken,
    output wire ret1, ret2
);

    reg [1:0] gshare_mem [0:255];
    integer i;
    initial begin
       for(i=0; i<256; i=i+1) gshare_mem[i] = 0;
    end
    
    // 分岐履歴レジスタ（BHR）
    reg [7:0] r_bhr = 0;
    always @(posedge clk) begin
        if (we) r_bhr <= {br_taken, r_bhr[7:1]};
    end
    
    wire [1:0] twobits_data1 = gshare_mem[raddr1 ^ r_bhr];
    assign ret1 = twobits_data1[1];
    wire [1:0] twobits_data2 = gshare_mem[raddr2 ^ r_bhr];
    assign ret2 = twobits_data2[1];
    
    wire [1:0] wcnt = gshare_mem[waddr ^ r_bhr];
    always @(posedge clk) begin
        if (we) gshare_mem[waddr ^ r_bhr] <= wcnt + ((wcnt < 3 & br_taken) ? 1 : (wcnt > 0 & !br_taken) ? -1 : 0);
    end
endmodule
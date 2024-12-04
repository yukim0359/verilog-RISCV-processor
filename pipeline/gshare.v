module gshare(
    input wire clk, we,
    input wire [4:0] waddr, raddr,
    input wire br_taken,
    output wire ret
);

    reg [1:0] mem [0:31];
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) mem[i] = 0;
    end
    
    // 分岐履歴レジスタ（BHR）
    reg [4:0] r_bhr = 0;
    always @(posedge clk) begin
        if (we) r_bhr <= {br_taken, r_bhr[4:1]};
    end
    
    wire [1:0] twobits_data = mem[raddr ^ r_bhr];
    assign ret = twobits_data[1];
    
    wire [1:0] wcnt = mem[waddr ^ r_bhr];
    always @(posedge clk) begin
        if (we)
 mem[waddr ^ r_bhr] <= (wcnt < 3 & br_taken) ? wcnt + 1 : (wcnt > 0 & !br_taken) ? wcnt - 1 : wcnt;
    end
endmodule
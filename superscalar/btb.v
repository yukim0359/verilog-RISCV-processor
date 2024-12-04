module btb(
    input wire clk,
    input wire [14:0] pc1, pc2,
    input wire [4:0] waddr,
    input wire we,
    input wire [23:0] wd,
    output wire btb_hit1, btb_hit2,
    output wire [14:0] pred_pc1, pred_pc2
);

    wire valid1, valid2;
    wire [7:0] tag1, tag2;
    wire [14:0] data1, data2;

    reg [23:0] btb_mem [0:31];
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) btb_mem[i] = 0;
    end

    always @(posedge clk) begin
        if (we) btb_mem[waddr] <= wd;
    end

    assign {valid1, tag1, data1} = btb_mem[pc1[6:2]];
    assign btb_hit1 = valid1 & (tag1 == pc1[14:7]);
    assign pred_pc1 = data1;

    assign {valid2, tag2, data2} = btb_mem[pc2[6:2]];
    assign btb_hit2 = valid2 & (tag2 == pc2[14:7]);
    assign pred_pc2 = data2;
endmodule
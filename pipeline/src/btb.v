module btb(
    input wire clk,
    input wire [16:0] pc,
    input wire [4:0] waddr,
    input wire we,
    input wire [27:0] wd,
    output wire btb_hit,
    output wire [16:0] pred_pc
);

    wire valid;
    wire [9:0] tag;
    wire [16:0] data;
    
    reg [27:0] mem [0:31];
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) mem[i] = 0;
    end
  
    always @(posedge clk) begin
        if (we) mem[waddr] <= wd;
    end

    assign {valid, tag, data} = mem[pc[6:2]];
    assign btb_hit = valid & (tag == pc[16:7]);
    assign pred_pc = data;
endmodule
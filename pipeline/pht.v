module pht(
    input wire clk,
    input wire [4:0] raddr, waddr,
    input wire we,
    input wire wd,
    output wire rd
);   
 
    reg [0:0] mem [0:31];
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) mem[i] = 0;
    end
    
    always @(posedge clk) begin
        if (we) mem[waddr] <= wd;
    end
    
    assign rd = mem[raddr];
    
endmodule
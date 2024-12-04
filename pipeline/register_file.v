`include "define.vh"

module register_file(
    input wire clk,
    input wire we,
    input wire [4:0] r_addr1,
    input wire [4:0] r_addr2,
    input wire [4:0] w_addr,
    input wire [31:0] w_data,
    output wire [31:0] r_data1,
    output wire [31:0] r_data2
);

    reg [31:0] registers [0:31];
    
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) registers[i] = 0;
    end

    always @(posedge clk) begin
        if(we) registers[w_addr] <= w_data;
    end
    
    assign r_data1 = registers[r_addr1];
    assign r_data2 = registers[r_addr2];

endmodule
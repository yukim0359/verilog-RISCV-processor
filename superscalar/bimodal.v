module bimodal(
    input wire clk, we,
    input wire [4:0] waddr, raddr1, raddr2,
    input wire br_taken,
    output wire ret1, ret2
);

    reg [1:0] bimodal_mem [0:31];
    integer i;
    initial begin
       for(i=0; i<32; i=i+1) bimodal_mem[i] = 1;
    end

    wire [1:0] twobits_data1 = bimodal_mem[raddr1];
    assign ret1 = twobits_data1[1];
    wire [1:0] twobits_data2 = bimodal_mem[raddr2];
    assign ret2 = twobits_data2[1];

    wire [1:0] wcnt = bimodal_mem[waddr];
    always @(posedge clk) begin
        if (we) bimodal_mem[waddr] <= wcnt + ((wcnt < 3 & br_taken) ? 1 : (wcnt > 0 & !br_taken) ? -1 : 0);
        // if (we) mem[waddr] <= (wcnt < 3 & br_taken) ? wcnt + 1 : (wcnt > 0 & !br_taken) ? wcnt - 1 : wcnt;
    end
endmodule
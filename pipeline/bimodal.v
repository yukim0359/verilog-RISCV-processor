module bimodal(
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

    wire [1:0] twobits_data = mem[raddr];
    assign ret = twobits_data[1];

    wire [1:0] wcnt = mem[waddr];
    always @(posedge clk) begin
        if (we) mem[waddr] <= wcnt + ((wcnt < 3 & br_taken) ? 1 : (wcnt > 0 & !br_taken) ? -1 : 0);
        // if (we) mem[waddr] <= (wcnt < 3 & br_taken) ? wcnt + 1 : (wcnt > 0 & !br_taken) ? wcnt - 1 : wcnt;
    end
endmodule
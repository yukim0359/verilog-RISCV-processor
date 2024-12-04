module register_file(raddr1, rdata1, raddr2, rdata2, raddr3, rdata3, raddr4, rdata4,
               we1, waddr1, wdata1, we2, waddr2, wdata2, clk);
    input  wire [4:0] raddr1;
    output wire[31:0] rdata1;
    input  wire [4:0] raddr2;
    output wire[31:0] rdata2;
    input  wire [4:0] raddr3;
    output wire[31:0] rdata3;
    input  wire [4:0] raddr4;
    output wire[31:0] rdata4;
    input  wire       we1;
    input  wire [4:0] waddr1;
    input  wire[31:0] wdata1;
    input  wire       we2;
    input  wire [4:0] waddr2;
    input  wire[31:0] wdata2;
    input  wire       clk;

    reg[31:0] register_b1[0:31];
    reg[31:0] register_b2[0:31];
    
    integer i;
    initial begin
        for(i=0; i<32; i=i+1) begin
            register_b1[i] = 32'b0;
            register_b2[i] = 32'b0;
        end
    end
    
    // initial register_b1[0] = 0;
    // initial register_b2[0] = 0;
    

    always @(posedge clk) begin
        if(we1) register_b1[waddr1] <= wdata1 ^ register_b2[waddr1];
        if(we2) register_b2[waddr2] <= wdata2 ^ register_b1[waddr2];
    end

    assign rdata1 = register_b1[raddr1] ^ register_b2[raddr1];
    assign rdata2 = register_b1[raddr2] ^ register_b2[raddr2];
    assign rdata3 = register_b1[raddr3] ^ register_b2[raddr3];
    assign rdata4 = register_b1[raddr4] ^ register_b2[raddr4];

    wire [31:0] register_val[0:31];
    genvar j;
    generate
        for (j=0; j<32; j=j+1) begin
            assign register_val[j] = register_b1[j] ^ register_b2[j];
        end
    endgenerate

endmodule

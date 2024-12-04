module instruction_memory(
    input wire clk,
    input wire [12:0] addr1, addr2,
    output reg [31:0] ir1, ir2
);

    reg [31:0] ir_mem [0:8191];

    initial begin
        // $readmemh("/home/denjo/b3exp/benchmarks/Coremark/code.hex", ir_mem);
        $readmemh("/home/denjo/b3exp/benchmarks/Coremark_for_Synthesis/code_cut_70MM.hex", ir_mem);
        // $readmemh("/home/denjo/b3exp/benchmarks/tests/ControlTransfer/code.hex", ir_mem);
    end

    always @(posedge clk) begin
        ir1 <= ir_mem[addr1];
        ir2 <= ir_mem[addr2];
    end

endmodule

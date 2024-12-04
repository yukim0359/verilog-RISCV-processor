`include "define.vh"

module instruction_memory(
    input wire clk,
    input wire [14:0] addr,
    output reg [31:0] ir
);

    reg [31:0] ir_mem [0:28000];

    initial begin
        // $readmemh("/home/denjo/b3exp/benchmarks/Coremark/code.hex", ir_mem);
        $readmemh("/home/denjo/b3exp/benchmarks/Coremark_for_Synthesis/code.hex", ir_mem);
        // $readmemh("/home/denjo/b3exp/benchmarks/tests/LoadAndStore/code.hex", ir_mem);
    end

    // クロックに同期して読み出し
    always @(posedge clk) begin
        ir <= ir_mem[addr];
    end

endmodule
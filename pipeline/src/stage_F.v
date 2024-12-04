`include "define.vh"

module stage_F(
    input wire clk,
    input wire reset,
    input wire stall,
    input wire w_miss,
    input wire [16:0] pc_in,
    output wire [16:0] w_pc,
    output wire [31:0] instruction
);
    
    reg[16:0] prev_pc;
    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            prev_pc <= 8192*4;
        end else begin
            prev_pc <= w_pc;
        end
    end
    
    assign w_pc = (w_miss | !stall/*!wait_load*/) ? pc_in : prev_pc;

    wire [14:0] instr_mem_addr = (!reset) ? 8191 : w_pc[16:2]; 
    instruction_memory instr_mem(
        .clk(clk),
        .addr(instr_mem_addr),
        .ir(instruction)
    );
    
endmodule
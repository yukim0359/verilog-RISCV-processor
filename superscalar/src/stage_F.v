module stage_F(
    input wire clk,
    input wire reset,
    input wire stall,
    input wire w_miss,
    input wire next_is_single,
    input wire [14:0] pc_in1, pc_in2,
    input wire [14:0] F_D_pc1, F_D_pc2,
    output wire [14:0] w_pc1, w_pc2,
    output wire [31:0] instruction1, instruction2
);

    wire fetch_both_instructions = w_miss | (!stall & !next_is_single);
    assign w_pc1 = (fetch_both_instructions) ? pc_in1 : (!stall) ? F_D_pc2 : F_D_pc1;
    assign w_pc2 = (fetch_both_instructions) ? pc_in2 : (!stall) ? pc_in1  : F_D_pc2;

    // resetの間はNOP命令が格納されているアドレスを指す
    wire [12:0] instr_mem_addr1 = (!reset) ? 8191 : w_pc1[14:2];
    wire [12:0] instr_mem_addr2 = (!reset) ? 8191 : w_pc2[14:2];

    instruction_memory instr_mem(
        .clk(clk),
        .addr1(instr_mem_addr1),
        .addr2(instr_mem_addr2),
        .ir1(instruction1),
        .ir2(instruction2)
    );

endmodule
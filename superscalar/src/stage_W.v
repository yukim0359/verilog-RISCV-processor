module stage_W(
    input wire [31:0] alu_result,
    input wire [31:0] mem_data,
    input wire [5:0] alucode,
    input wire [31:0] hc_OUT_data,
    input wire [4:0] byte_offset,
    input wire is_hardware,
    output wire [31:0] wb_data
);

    wire is_lb   = (alucode == `ALU_LB);
    wire is_lh   = (alucode == `ALU_LH);
    wire is_lw   = (alucode == `ALU_LW);
    wire is_lbu  = (alucode == `ALU_LBU);
    wire is_lhu  = (alucode == `ALU_LHU);

    // wire is_hardware = (addr == `HARDWARE_COUNTER_ADDR);
    // wire [4:0] byte_offset = addr[1:0] * 8;

    assign wb_data =
            (is_lb)               ? {{24{mem_data[byte_offset + 7]}}, mem_data[byte_offset +: 8]} : 
            (is_lbu)              ? {24'b0, mem_data[byte_offset +: 8]} : 
            (is_lh)               ? {{16{mem_data[byte_offset + 15]}}, mem_data[byte_offset +: 16]} : 
            (is_lhu)              ? {16'b0, mem_data[byte_offset +: 16]} : 
            (is_lw & is_hardware) ? hc_OUT_data : 
            (is_lw)               ? mem_data : 
                                    alu_result;

endmodule
module cpu_tb;
    reg sysclk;
    reg cpu_resetn;
    wire uart_tx;

    parameter CYCLE = 0.1;

    always #(CYCLE/2) sysclk = ~sysclk;

    cpu cpu0(
       .sysclk(sysclk),
       .cpu_resetn(cpu_resetn),
       .uart_tx(uart_tx)
    );

    initial begin
        #1     sysclk     = 1'd0;
                cpu_resetn    = 1'd0;
        #(CYCLE) cpu_resetn = 1'd1;
        #(200000) $finish;
        // #(100) $finish;
        // #(2) $finish;
    end
endmodule
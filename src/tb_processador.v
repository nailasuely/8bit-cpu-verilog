
`timescale 1ns/1ps

module tb_processador;
    reg clk;
    reg rst;
    wire [7:0] debug_A;
    wire [7:0] debug_B;
    wire [7:0] debug_PC;
    wire [3:0] debug_State;

    processador_8bits DUT (
        .clk(clk),
        .rst(rst),
        .debug_A(debug_A),
        .debug_B(debug_B),
        .debug_PC(debug_PC),
        .debug_State(debug_State)
    );

    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    initial begin
        $dumpfile("processador.vcd");
        $dumpvars(0, tb_processador);

        rst = 1;
        #40;
        rst = 0;

        #1200;
        $stop;
    end
endmodule

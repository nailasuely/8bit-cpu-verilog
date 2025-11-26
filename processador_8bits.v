`timescale 1ns/1ps

// Módulo da ULA
module alu_unit (
    input  [7:0] op_a,
    input  [7:0] op_b,
    input  [3:0] opcode,
    output reg [7:0] result,
    output reg is_zero
);
    localparam ADD = 4'h0;
    localparam SUB = 4'h1;
    localparam AND_OP = 4'h8;
    localparam OR_OP  = 4'h9;

    always @(*) begin
        case (opcode)
            ADD: result = op_a + op_b;
            SUB: result = op_a - op_b;
            AND_OP: result = op_a & op_b;
            OR_OP:  result = op_a | op_b;
            default: result = 8'h00;
        endcase
        is_zero = (result == 8'd0);
    end
endmodule

// Módulo da ROM
module program_memory (
    input  [7:0] addr,
    output reg [15:0] data_out
);
    // Opcodes
    localparam ADD = 4'h0; 
    localparam SUB = 4'h1; 
    localparam LDA = 4'h2;
    localparam STA = 4'h3; 
    localparam LDB = 4'h4; 
    localparam STB = 4'h5;
    localparam LDC = 4'h6; 
    localparam JMP = 4'h7; 
    localparam SWAP = 4'h8;
    localparam JNZ = 4'h9; 
    localparam LDC_B = 4'hA; 
    localparam HLT = 4'hF;

    reg [15:0] rom [0:255];
    integer i;

    initial begin
        for (i=0; i<256; i=i+1)
            rom[i] = {HLT, 4'b0000, 8'd0};

        // PROGRAMA DE TESTE
        rom[0]  = {LDC,   4'b0000, 8'd5};    // A = 5
        rom[1]  = {LDC_B, 4'b0000, 8'd3};    // B = 3
        rom[2]  = {ADD,   4'b0000, 8'd100};  // Mem[100] = A+B
        rom[3]  = {SUB,   4'b0000, 8'd101};  // Mem[101] = A-B
        rom[4]  = {SWAP,  4'b0000, 8'd0};    // swap A,B
        rom[5]  = {LDC,   4'b0000, 8'd1};    // A = 1
        rom[6]  = {STA,   4'b0000, 8'd200};  // Mem[200] = A
        rom[7]  = {LDC,   4'b0000, 8'd0};    // A = 0
        rom[8]  = {JMP,   4'b0000, 8'd10};   // salta
        rom[9]  = {LDC,   4'b0000, 8'hFF};   // ignorado
        rom[10] = {LDA,   4'b0000, 8'd100};  // A = Mem[100]
        rom[11] = {JNZ,   4'b0000, 8'd13};   // se A!=0, salta
        rom[12] = {HLT,   4'b0000, 8'd0};
        rom[13] = {HLT,   4'b0000, 8'd0};
    end

    always @(*) begin
        data_out = rom[addr];
    end
endmodule

// Módulo da RAM
module data_memory (
    input clk,
    input we,
    input [7:0] addr,
    input [7:0] data_in,
    output reg [7:0] data_out
);
    reg [7:0] ram [0:255];
    integer k;

    initial begin
        for (k=0; k<256; k=k+1) ram[k] = 8'd0;
    end

    always @(posedge clk) begin
        if (we) ram[addr] <= data_in;
    end

    always @(*) begin
        data_out = ram[addr];
    end
endmodule

//Módulo Principal 
module processador_8bits (
    input wire clk,
    input wire rst,
    output [7:0] debug_A,
    output [7:0] debug_B,
    output [7:0] debug_PC,
    output [3:0] debug_State
);
    reg [7:0] PC, A, B;
    reg [15:0] IR;
    reg [1:0] state;
    
    wire [7:0] alu_result;
    wire alu_zero;
    wire [15:0] rom_data;
    wire [7:0] ram_q;
    
    reg ram_we;
    reg [7:0] ram_data_in;
    wire [7:0] ram_addr;

    alu_unit ULA (.op_a(A), .op_b(B), .opcode(IR[15:12]), .result(alu_result), .is_zero(alu_zero));
    program_memory ROM (.addr(PC), .data_out(rom_data));
    data_memory RAM (.clk(clk), .we(ram_we), .addr(ram_addr), .data_in(ram_data_in), .data_out(ram_q));

    localparam FETCH=0, EXECUTE=1, HALT=2;
    localparam ADD=0, SUB=1, LDA=2, STA=3, LDB=4, STB=5, LDC=6, JMP=7, SWAP=8, JNZ=9, LDCB=10, HLT=15;

    assign debug_A = A;
    assign debug_B = B;
    assign debug_PC = PC;
    assign debug_State = {2'b00, state};

    assign ram_addr = IR[7:0];

    always @(*) begin
        ram_we = 0;
        ram_data_in = 0;
        if (state == EXECUTE) begin
            case (IR[15:12])
                STA, STB:
                    begin ram_we = 1; ram_data_in = (IR[15:12] == STA) ? A : B; end
                ADD, SUB:
                    begin ram_we = 1; ram_data_in = alu_result; end
            endcase
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            PC <= 0; A <= 0; B <= 0; IR <= 0; state <= FETCH;
        end else begin
            case (state)
                FETCH: begin
                    IR <= rom_data;
                    PC <= PC + 1;
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    case (IR[15:12])
                        LDA: A <= ram_q;
                        LDB: B <= ram_q;
                        LDC: A <= IR[7:0];
                        LDCB: B <= IR[7:0];
                        SWAP: begin A <= B; B <= A; end
                        JMP: if (A == 0) PC <= IR[7:0];
                        JNZ: if (A != 0) PC <= IR[7:0];
                        HLT: state <= HALT;
                    endcase
                    if (IR[15:12] != HLT) state <= FETCH;
                end

                HALT: state <= HALT;
            endcase
        end
    end
endmodule

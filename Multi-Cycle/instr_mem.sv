`timescale 1ns / 1ps

module instr_mem (
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);
    logic [31:0] instr_rom[0:127];

    initial begin
        $readmemh("instruction_code.mem", instr_rom);
    end

    assign instr_code = instr_rom[instr_addr[31:2]];
endmodule


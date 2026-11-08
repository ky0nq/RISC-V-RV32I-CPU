`timescale 1ns / 1ps

module instruction_mem (
    input logic clk,
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);
    logic [31:0] instr_rom[0:127];

    // initialize for simulation 
    `ifdef TEST_SIMULATION
        int i;
        initial begin
            instr_rom[0] = 32'h0031_02b3;  // x5 = x2 + x3 
            instr_rom[1] = 32'h0041_82b3;  // x5 = x3 + x4 
            instr_rom[2] = 32'h0031_2123;  // sw x2, x3, 2 : rs1, rs2, imm
            instr_rom[3] = 32'h0021_2403;  // lw x8, x2, 2 : rd, rs1, imm
            instr_rom[4] = 32'h0043_8413;  // addi x8, x7, 4 : rd, rs1, imm
            instr_rom[5] = 32'hfe84_0ce3; // BEQ x8, x8, -8 : rs1, rs2, imm / PC = PC + imm 
        end
    `endif

    `ifdef TEST_SIMULATION_I
        instr_rom[ 0] = 32'h00508513;  // ADDI  x10 = x1 + 5   = 6
        instr_rom[ 1] = 32'h4011D593;  // SRAI  x11 = x3 >>> 1 = 0xFFFFFFFF  (MSB extension)
        instr_rom[ 2] = 32'h0001A613;  // SLTI  x12 = ((signed) x3 < 0) = 1  (-1 < 0)
    `endif

   `ifdef TEST_SIMULATION_S_IL
        initial begin
            instr_rom[ 0] = 32'h00112023;  // SW   mem[ 0] => x1 → mem[ 0] = 0x00000001
            instr_rom[ 1] = 32'h00012503;  // LW   mem[ 0] → x10 = 0x00000001

            instr_rom[ 2] = 32'h00312223;  // SW   mem[ 1] => x3 → mem[ 1] = 0xFFFFFFFF
            instr_rom[ 3] = 32'h00412583;  // LW   mem[ 1] → x11 = 0xFFFFFFFF

            instr_rom[ 4] = 32'h00310423;  // SB   mem[ 2][7:0] => x3(32'h0000_00FF) → mem[ 2] = 0x......FF
            instr_rom[ 5] = 32'h00810603;  // LB   mem[ 2] → x12 = 0xFFFFFFFF (MSB extension)
            instr_rom[ 6] = 32'h00814683;  // LBU  mem[ 2] → x13 = 0x000000FF (Zero extension)

            instr_rom[ 7] = 32'h00311723;  // SH   mem[3][31:16] x3(32'h0000_FFFF) → mem[3] = 0xFFFF....
            instr_rom[ 8] = 32'h00E11703;  // LH   mem[3] → x14 = 0xFFFFFFFF (MSB extension)
            instr_rom[ 9] = 32'h00E15783;  // LHU  mem[3] → x15 = 0x0000FFFF (Zero extension)
        end
    `endif

    `ifdef TEST_SIMULATION_U
        initial begin 
            instr_rom[0] = 32'h12345537;  // LUI   x10 = 0x12345000
            instr_rom[1] = 32'h00001597;  // AUIPC x11 = PC(0x04) + 0x1000    = 0x00001004
            instr_rom[2] = 32'h00000637;  // LUI   x12 = 0x00000000            
            instr_rom[3] = 32'hFFFFF697;  // AUIPC x13 = PC(0x0C) + 0xFFFFF000 = 0xFFFFF00C
        end
    `endif

    `ifdef TEST_SIMULATION_B_J_JL
        initial begin
            instr_rom[0] = 32'h00208463;  // BEQ  x1 == x2 (1 == 1) -> instr_rom[2] branch
            instr_rom[1] = 32'h00000013;  // NOP 
            instr_rom[2] = 32'h0041C463;  // BLT  (signed) x3 < x4 (-1 < 2) -> instr_rom[4] branch
            instr_rom[3] = 32'h00000013;  // NOP 
            instr_rom[4] = 32'h0041E463;  // BLTU x3 < x4 (32'hFFFFFFFF > 2) → PC + 4 (no branch)
            instr_rom[5] = 32'h0080056F;  // JAL  x10 = PC + 4 -> instr_rom[7] jump
            instr_rom[6] = 32'h00000013;  // NOP  
            instr_rom[7] = 32'h00050067;  // JALR PC = PC + Imm => current PC == return
            instr_rom[8] = 32'h00000013;  // NOP
        end
    `endif

    // bubble sort instruction code
//    `ifdef TEST_BUBBLE_SORT_C_ASM
        initial begin
            $readmemh("instruction_code.mem", instr_rom);
        end
//    `endif 

    assign instr_code = instr_rom[instr_addr[31:2]]; // for word addressing
endmodule


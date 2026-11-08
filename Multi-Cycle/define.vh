
// OP-CODE instruction code [6:0]
`define R_TYPE 7'b011_0011
`define S_TYPE 7'b010_0011
`define IL_TYPE 7'b000_0011
`define I_TYPE 7'b001_0011
`define B_TYPE 7'b110_0011
`define UL_TYPE 7'b011_0111 // LUI
`define UA_TYPE 7'b001_0111 // AUIPC
`define J_TYPE 7'b110_1111  // JAL
`define JL_TYPE 7'b110_0111 // JALR

// R-type instruction
// I-type instruction (share R-type)
// {funct7[5], funct3} = 4-bit
// optimization alu_control_signal
`define ADD 4'b0000 
`define SUB 4'b1000  
`define SLL 4'b0001
`define SLT 4'b0010
`define SLTU 4'b0011
`define XOR 4'b0100
`define SRL 4'b0101
`define SRA 4'b1101
`define OR 4'b0110
`define AND 4'b0111

// S-type instruction
// funct3 = 3-bit
`define SB 3'b000
`define SH 3'b001 
`define SW 3'b010

// IL-type instruction
`define LB 3'b000
`define LH 3'b001
`define LW 3'b010
`define LBU 3'b100
`define LHU 3'b101

// B-type instruction
`define BEQ 3'b000
`define BNE 3'b001
`define BLT 3'b100
`define BGE 3'b101
`define BLTU 3'b110
`define BGEU 3'b111
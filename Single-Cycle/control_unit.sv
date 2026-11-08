
`timescale 1ns / 1ps
`include "define.vh"

module control_unit (
    input  logic [31:0] instr_code, // RV32I

    // register file write enable signal
    output logic        rf_we,

    // for Program Counter
    output logic        branch,
    output logic        jal,
    output logic        jalr,

    // alu operation control
    output logic        alusrc_sel,
    output logic [ 3:0] alu_control,

    // write back MUX source select
    output logic [ 2:0] rfsrc_sel,

    // data memory 
    output logic [ 2:0] mem_mode,
    output logic        dwe
);

    logic [6:0] funct7; // for alu operation information
    logic [2:0] funct3; // alu operation or mem_mode
    logic [6:0] opcode; // opcode

    assign funct7 = instr_code[31:25];
    assign funct3 = instr_code[14:12];
    assign opcode = instr_code[6:0];
    
// for debug print ===================================================================================================
//    // [DEBUG]
//    typedef enum logic [6:0] {
//        DBG_R_TYPE  = `R_TYPE,
//        DBG_S_TYPE  = `S_TYPE,
//        DBG_IL_TYPE = `IL_TYPE,
//        DBG_I_TYPE  = `I_TYPE,
//        DBG_B_TYPE  = `B_TYPE,
//        DBG_UL_TYPE = `UL_TYPE,
//        DBG_UA_TYPE = `UA_TYPE,
//        DBG_J_TYPE  = `J_TYPE,
//        DBG_JL_TYPE = `JL_TYPE
//    } opcode_dbg_e;
//    opcode_dbg_e opcode_dbg;
//    assign opcode_dbg = opcode_dbg_e'(opcode);
//
//    // [DEBUG] alu_control
//    typedef enum logic [3:0] {
//        DBG_ALU_ADD  = `ADD,   // 4'b0000
//        DBG_ALU_SLL  = `SLL,   // 4'b0001
//        DBG_ALU_SLT  = `SLT,   // 4'b0010
//        DBG_ALU_SLTU = `SLTU,  // 4'b0011
//        DBG_ALU_XOR  = `XOR,   // 4'b0100
//        DBG_ALU_SRL  = `SRL,   // 4'b0101
//        DBG_ALU_OR   = `OR,    // 4'b0110
//        DBG_ALU_AND  = `AND,   // 4'b0111
//        DBG_ALU_SUB  = `SUB,   // 4'b1000
//        DBG_ALU_SRA  = `SRA    // 4'b1101
//    } alu_control_dbg_e;
//    alu_control_dbg_e alu_control_dbg;
//    assign alu_control_dbg = alu_control_dbg_e'(alu_control);
// ===================================================================================================================
    always_comb begin
        rf_we = 0;
        branch = 0;
        jal = 0;
        jalr = 0;
        alusrc_sel = 0;
        rfsrc_sel = 3'd0;
        mem_mode = 3'd0;
        alu_control = 0;
        dwe = 0;
        case (opcode)
            `R_TYPE: begin
                rf_we = 1;          // register file write enable signal
                branch = 0;
                jal = 0;
                jalr = 0;
                alusrc_sel = 0;
                rfsrc_sel = 0;
                mem_mode = 3'd0;
                alu_control = {funct7[5], funct3};
                dwe = 0;
            end
            `S_TYPE: begin
                rf_we = 0;      
                branch = 0;
                jal = 0;
                jalr = 0;
                alusrc_sel = 1;
                rfsrc_sel = 0;
                mem_mode = funct3;  // alignment information
                alu_control = `ADD; // memory address = rs1 + Imm
                dwe = 1;            // memory write enable signal
            end
            `IL_TYPE: begin
                rf_we = 1;          // register file write enable signal
                branch = 0;
                jal = 0;
                jalr = 0;
                alusrc_sel = 1;     // rs1 + imm
                rfsrc_sel = 1;      // from data memory 
                mem_mode = funct3;  // alignment information
                alu_control = `ADD; // memory address = rs1 + Imm
                dwe = 0;
            end
            `I_TYPE: begin
                rf_we = 1;          // register file write enable signal
                branch = 0;
                jal = 0;
                jalr = 0;
                alusrc_sel = 1;     // rs1 + imm
                rfsrc_sel = 0;      // alu result
                mem_mode = 3'd0;
                if (funct3 == 3'b101) alu_control = {funct7[5], funct3}; // share R-type alu_control signal
                else alu_control = {1'b0, funct3}; // share R-type alu_control signal
                dwe = 0;
            end
            `B_TYPE: begin
                rf_we = 0;
                branch = 1;
                jal = 0;
                jalr = 0;
                alusrc_sel = 0;     // rs1 + rs2
                rfsrc_sel = 0;  
                mem_mode = 3'd0;
                alu_control = {1'b0, funct3};
                dwe = 0;
            end
            `UL_TYPE, `UA_TYPE: begin
                rf_we = 1;          // register file write enable signal
                branch = 0;
                jal = 0;
                jalr = 0;
                alusrc_sel = 0;  
                if (opcode == `UA_TYPE) rfsrc_sel = 3'd3; // PC + Imm
                else rfsrc_sel = 3'd2; // Imm
                mem_mode = 3'd0;
                alu_control = 4'd0;
                dwe = 0;
            end
            `J_TYPE, `JL_TYPE: begin
                rf_we = 1;          // register file write enable signal
                branch = 0;
                jal = 1;
                if (opcode == `JL_TYPE) jalr = 1; // PC = rs1 + Imm
                else jalr = 0;                    // PC = PC + Imm
                alusrc_sel = 0;
                rfsrc_sel = 3'd4;
                mem_mode = 3'd0;
                alu_control = 4'd0;
                dwe = 0;
            end
        endcase
    end

endmodule

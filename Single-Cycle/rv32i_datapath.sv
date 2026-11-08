`timescale 1ns / 1ps
`include "define.vh"

module datapath (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instr_code,
    input  logic        rf_we,
    input  logic        branch,
    input  logic        jal,
    input  logic        jalr,
    input  logic        alusrc_sel,
    input  logic [ 3:0] alu_control,
    input  logic [ 2:0] rfsrc_sel,
    input  logic [31:0] drdata,
    output logic [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata,
    output logic [31:0] wb_out
);
    logic [31:0] rs1, rs2, alu_result, imm_extend, alu_rs2_mux;
    logic [31:0] pc_imm, pc_4;
    logic b_taken;
    
    // for implementation  =====
    logic [31:0] wb_data;
    assign wb_out = wb_data;
    // =========================

    assign daddr  = alu_result;
    assign dwdata = rs2;

    mux_wb U_WB_MUX (
        .in0   (alu_result),
        .in1   (drdata),
        .in2   (imm_extend),
        .in3   (pc_imm),
        .in4   (pc_4),
        .sel   (rfsrc_sel),
        .wb_out(wb_data)
    );

    register_file U_REG_FILE (
        .clk   (clk),
        .raddr1(instr_code[19:15]),
        .raddr2(instr_code[24:20]),
        .waddr (instr_code[11:7]),
        .rf_we (rf_we),
        .wdata (wb_data),
        .rdata1(rs1),
        .rdata2(rs2)
    );

    imm_extend U_IMM_EXTEND (
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    alu U_ALU (
        .alu_control(alu_control),
        .rs1        (rs1),          // rs1
        .rs2        (alu_rs2_mux),  // rs2
        .alu_result (alu_result),   // rd
        .b_taken    (b_taken)
    );

    mux_2x1 U_ALU_RS2_MUX (
        .in0    (rs2),
        .in1    (imm_extend),
        .sel    (alusrc_sel),
        .out_mux(alu_rs2_mux)
    );

    program_counter U_PC (
        .clk       (clk),
        .rst       (rst),
        .b_taken   (b_taken),
        .branch    (branch),
        .jalr      (jalr),
        .jal       (jal),
        .rs1       (rs1),
        .pc_in     (instr_addr),  // for next program count
        .imm_extend(imm_extend),
        .pc_out    (instr_addr),  // for current program count
        .pc_imm    (pc_imm),
        .pc_4      (pc_4)
    );
endmodule

// =========================================================================
// Module Code
// =========================================================================
module register_file (
    input  logic        clk,
    input  logic [ 4:0] raddr1,  // rs1
    input  logic [ 4:0] raddr2,  // rs2
    input  logic [ 4:0] waddr,   // register file write enable
    input  logic [31:0] wdata,
    input  logic        rf_we,
    output logic [31:0] rdata1,  // rs1 read data
    output logic [31:0] rdata2   // rs2 read data
);
    logic [31:0] register_file[1:31];

// initialize for simulation =======================================================
    `ifdef TEST_SIMULATION
        int i = 0;
        initial begin
            for (i = 1; i < 32; i = i + 1) register_file[i] = i;
            //register_file[1] = 32'd1;
            //register_file[2] = -32'd6;
            //register_file[3] = 32'd5;
            //register_file[1] = 32'd1;
            //register_file[2] = -32'd6;
            //register_file[3] = 32'd5;
        end
    `endif
    
    `ifdef TEST_SIMULATION_I
        initial begin
            register_file[1] = 32'h00000001;  // x1 = 1
            register_file[2] = 32'h00000004;  // x2 = 4  (word-aligned base addr)
            register_file[3] = 32'hFFFFFFFF;  // x3 = -1
        end
    `endif
    
    `ifdef TEST_SIMULATION_S_IL
        initial begin
            register_file[1] = 32'h00000001;  // x1 = 1
            register_file[2] = 32'h00000000;  // x2 = 0  
            register_file[3] = 32'hFFFFFFFF;  // x3 = -1 
        end
    `endif
    
    `ifdef TEST_SIMULATION_B_J_JL
        initial begin
            register_file[1] = 32'h00000001;  // x1 = 1
            register_file[2] = 32'h00000001;  // x2 = 1
            register_file[3] = 32'hFFFFFFFF;  // x3 = -1
            register_file[4] = 32'h00000002;  // x4 = 2
        end
    `endif  
    // ===============================================================================

    always_ff @(posedge clk) begin
        if (rf_we) begin
            register_file[waddr] <= wdata;
        end
    end
    // read data uses combinational logic for one cycle operation
    // condition makes that reset signal not use
    assign rdata1 = (raddr1) ? register_file[raddr1] : 32'd0;
    assign rdata2 = (raddr2) ? register_file[raddr2] : 32'd0;

endmodule

// transition immediate #bit to 32-bit
module imm_extend (
    input  logic [31:0] instr_code,
    output logic [31:0] imm_extend
);
    always_comb begin
        imm_extend = 32'd0;
        case (instr_code[6:0]) // instr_code[6:0] == opcode
            `S_TYPE:
            imm_extend = {
                {20{instr_code[31]}}, instr_code[31:25], instr_code[11:7]
            };
            `IL_TYPE, `I_TYPE, `JL_TYPE:
            imm_extend = {{20{instr_code[31]}}, instr_code[31:20]};
            `B_TYPE:
            imm_extend = {
                {20{instr_code[31]}},   // imm[12]
                instr_code[7],          // imm[11]
                instr_code[30:25],      // imm[10:5]
                instr_code[11:8],       // imm[4:1]
                1'b0                    // imm[0] = 0
            };
            `UA_TYPE, `UL_TYPE: imm_extend = {instr_code[31:12], 12'h000}; // apply upper immediate extension
            `J_TYPE:
            imm_extend = {
                {13{instr_code[31]}}, // imm[20]          
                instr_code[19:12],    // imm[19:12] 
                instr_code[20],       // imm[11]          
                instr_code[30:21],    // imm[10:1]     
                1'b0                  // imm[0] = 0         
            };
        endcase
    end
endmodule

module alu (
    input  logic [ 3:0] alu_control,
    input  logic [31:0] rs1,
    input  logic [31:0] rs2,
    output logic [31:0] alu_result,
    output logic        b_taken
);

    // B-type branch condition ============================================
    always_comb begin
        b_taken = 1'b0;
        case (alu_control[2:0])
            `BEQ: begin
                if (rs1 == rs2) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
            `BNE: begin
                if (rs1 != rs2) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
            `BLT: begin
                if ($signed(rs1) < $signed(rs2)) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
            `BGE: begin
                if ($signed(rs1) >= $signed(rs2)) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
            `BLTU: begin
                if (rs1 < rs2) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
            `BGEU: begin
                if (rs1 >= rs2) b_taken = 1'b1;
                else b_taken = 1'b0;
            end
        endcase
    end
    // ===================================================================

    // R-type, I-type ====================================================
    always_comb begin
        alu_result = 0;
        case (alu_control)
            // R-Type RD = RS1 + RS2
            // I-Type RD = RS1 + IMM(RS2)
            `ADD:  alu_result = rs1 + rs2;
            `SUB:  alu_result = rs1 - rs2;
            `SLL:  alu_result = rs1 << rs2[4:0];
            `SLT:  alu_result = (($signed(rs1) < $signed(rs2)) ? 1 : 0);
            `SLTU: alu_result = ((rs1 < rs2) ? 1 : 0);
            `XOR:  alu_result = rs1 ^ rs2;
            `SRL:  alu_result = (rs1 >> rs2[4:0]);
            `SRA:  alu_result = $signed(rs1) >>> rs2[4:0];
            `OR:   alu_result = rs1 | rs2;
            `AND:  alu_result = rs1 & rs2;
        endcase
    end
    // ===================================================================
endmodule

module mux_2x1 (
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic        sel,
    output logic [31:0] out_mux
);

    assign out_mux = sel ? in1 : in0;
endmodule

// register file write data select mux
module mux_wb (
    input  logic [31:0] in0,
    input  logic [31:0] in1,
    input  logic [31:0] in2,
    input  logic [31:0] in3,
    input  logic [31:0] in4,
    input  logic [ 2:0] sel,
    output logic [31:0] wb_out
);

    always_comb begin
        wb_out = 32'd0;
        case (sel)
            3'b000: wb_out = in0;  // load alu
            3'b001: wb_out = in1;  // load data memory
            3'b010: wb_out = in2;  // load LUI : Load Upper Imm
            3'b011: wb_out = in3;  // load Add Upper IMM to PC
            3'b100: wb_out = in4;  // load JAL, JARL : PC + 4
        endcase
    end
endmodule

module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        b_taken,
    input  logic        branch,
    input  logic        jalr,
    input  logic        jal,
    input  logic [31:0] rs1,
    input  logic [31:0] pc_in,
    input  logic [31:0] imm_extend,
    output logic [31:0] pc_out,
    output logic [31:0] pc_imm,
    output logic [31:0] pc_4
);
    logic [31:0] pc_reg, pc_next;
    logic [31:0] pc_jalr;

    assign pc_out = pc_reg;
    assign pc_imm = imm_extend + pc_jalr;
    assign pc_4   = pc_in + 4;

    // JALR - rs1 select 
    mux_2x1 U_PC_JALR_MUX (
        .in0    (pc_in),
        .in1    (rs1),
        .sel    (jalr),
        .out_mux(pc_jalr)
    );

    // next PC select
    mux_2x1 U_PC_SRC_MUX (
        .in0    (pc_4),     // always calculate next instruction code address
        .in1    (pc_imm),   // unconditional , conditional jump
        .sel    ((jal | jalr) | (branch & b_taken)),
        .out_mux(pc_next)
    );

    // register 
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            pc_reg <= 0;
        end else begin
            pc_reg <= pc_next;
        end
    end
endmodule

// =========================================================================
// =========================================================================

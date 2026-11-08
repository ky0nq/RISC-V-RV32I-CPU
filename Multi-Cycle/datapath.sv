`timescale 1ns / 1ps
`include "define.vh"

module datapath (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instr_code,
    input  logic        pc_en, // for FETCH phase FF
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
    output logic [31:0] wb_out // output for implementation 
);
    logic [31:0] rs1, rs2, alu_result, imm_extend, alu_rs2_mux;
    logic [31:0] pc_imm, pc_4;
    logic b_taken;
    
    logic [31:0] wb_data;
    assign wb_out = wb_data;

    // DEC to EXE register 
    logic [31:0] o_dec_rs1, o_dec_rs2, o_dec_imm_e;
    logic [31:0] o_exe_alu, o_exe_rs2;

    logic [31:0] o_wb_drdata;

    assign daddr  = o_exe_alu;
    assign dwdata = o_exe_rs2;

    register_s U_WB_DRDATA (
        .clk(clk),
        .rst(rst),
        .in (drdata),
        .out(o_wb_drdata)
    );

    mux_wb U_WB_MUX (
        .in0   (alu_result),
        .in1   (o_wb_drdata),
        .in2   (o_dec_imm_e),
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

    register_s U_DEC_RS1 (
        .clk(clk),
        .rst(rst),
        .in (rs1),
        .out(o_dec_rs1)
    );

    register_s U_DEC_RS2 (
        .clk(clk),
        .rst(rst),
        .in (rs2),
        .out(o_dec_rs2)
    );

    imm_extend U_IMM_EXTEND (
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    register_s U_DEC_IMM (
        .clk(clk),
        .rst(rst),
        .in (imm_extend),
        .out(o_dec_imm_e)
    );

    alu U_ALU (
        .alu_control(alu_control),
        .rs1        (o_dec_rs1),    // rs1
        .rs2        (alu_rs2_mux),  // rs2
        .alu_result (alu_result),   // rd
        .b_taken    (b_taken)
    );

    mux_2x1 U_ALU_RS2_MUX (
        .in0    (o_dec_rs2),
        .in1    (o_dec_imm_e),
        .sel    (alusrc_sel),
        .out_mux(alu_rs2_mux)
    );

    program_counter U_PC (
        .clk       (clk),
        .rst       (rst),
        .pc_en     (pc_en),
        .b_taken   (b_taken),
        .branch    (branch),
        .jalr      (jalr),
        .jal       (jal),
        .rs1       (o_dec_rs1),
        .pc_in     (instr_addr),
        .imm_extend(o_dec_imm_e),
        .pc_out    (instr_addr),
        .pc_imm    (pc_imm),
        .pc_4      (pc_4)
    );

    register_s U_EXE_ALU (
        .clk(clk),
        .rst(rst),
        .in (alu_result),
        .out(o_exe_alu)
    );

    register_s U_EXE_RS2 (
        .clk(clk),
        .rst(rst),
        .in (o_dec_rs2),
        .out(o_exe_rs2)
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

    always_ff @(posedge clk) begin
        if (rf_we) begin
            register_file[waddr] <= wdata;
        end
    end
    assign rdata1 = (raddr1) ? register_file[raddr1] : 32'd0;
    assign rdata2 = (raddr2) ? register_file[raddr2] : 32'd0;

endmodule

module imm_extend (
    input  logic [31:0] instr_code,
    output logic [31:0] imm_extend
);
    always_comb begin
        imm_extend = 32'd0;
        case (instr_code[6:0])
            `S_TYPE:
            imm_extend = {
                {20{instr_code[31]}}, instr_code[31:25], instr_code[11:7]
            };
            `IL_TYPE, `I_TYPE, `JL_TYPE:
            imm_extend = {{20{instr_code[31]}}, instr_code[31:20]};
            `B_TYPE:
            imm_extend = {
                {20{instr_code[31]}},
                instr_code[7],
                instr_code[30:25],
                instr_code[11:8],
                1'b0
            };
            `UA_TYPE, `UL_TYPE: imm_extend = {instr_code[31:12], 12'h000};
            `J_TYPE:
            imm_extend = {
                {13{instr_code[31]}},
                instr_code[19:12],
                instr_code[20],
                instr_code[30:21],
                1'b0
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

    // B-type branch condition
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

    // R-type, I-type
    always_comb begin
        alu_result = 0;
        case (alu_control)
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
            3'b000: wb_out = in0;
            3'b001: wb_out = in1;
            3'b010: wb_out = in2;
            3'b011: wb_out = in3;
            3'b100: wb_out = in4;
        endcase
    end
endmodule

module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic        pc_en,
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
    logic [31:0] o_exe_pc_next;

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
        .in0(pc_4),
        .in1(pc_imm),
        .sel((jal | jalr) | (branch & b_taken)),
        .out_mux(pc_next)
    );

    register_s U_EXE_PC_NEXT (
        .clk(clk),
        .rst(rst),
        .in (pc_next),
        .out(o_exe_pc_next)
    );

    // PC register 
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            pc_reg <= 0;
        end else begin
            if (pc_en) begin
                pc_reg <= o_exe_pc_next;
            end
        end
    end
endmodule

module register_s (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] in,
    output logic [31:0] out
);
    logic [31:0] register;
    assign out = register;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            register <= 0;
        end else begin
            register <= in;
        end
    end
endmodule
// =========================================================================
// =========================================================================

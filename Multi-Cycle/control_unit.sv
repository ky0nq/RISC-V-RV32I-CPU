`timescale 1ns / 1ps
`include "define.vh"

// Multi-Cycle Control Unit : FSM-based (Sequential Logic)
// States : FETCH -> DECODE -> EXECUTE -> (MEM) -> (WB)

module control_unit (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instr_code,
    output logic        pc_en,
    output logic        rf_we,
    output logic        branch,
    output logic        jal,
    output logic        jalr,
    output logic        alusrc_sel,
    output logic [ 3:0] alu_control,
    output logic [ 2:0] rfsrc_sel,
    output logic [ 2:0] mem_mode,
    output logic        dwe
);

    logic [6:0] funct7;
    logic [2:0] funct3;
    logic [6:0] opcode;

    assign funct7 = instr_code[31:25];
    assign funct3 = instr_code[14:12];
    assign opcode = instr_code[6:0];

    typedef enum logic [2:0] {
        FETCH,
        DECODE,
        EXECUTE,
        MEM,
        WB
    } state_e;
    state_e c_state, n_state;

    // state sequential logic
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            c_state <= FETCH;
        end else begin
            c_state <= n_state;
        end
    end

    // state combinational logic 
    always_comb begin
        n_state = c_state;
        case (c_state)
            FETCH: n_state = DECODE;
            DECODE: n_state = EXECUTE;
            EXECUTE: begin
                case (opcode)
                    `R_TYPE, `I_TYPE, `B_TYPE, `UL_TYPE, `UA_TYPE, `J_TYPE, `JL_TYPE: begin
                        n_state = FETCH;
                    end
                    `S_TYPE, `IL_TYPE: begin
                        n_state = MEM;
                    end
                endcase
            end
            MEM: begin
                if (opcode == `S_TYPE) begin
                    n_state = FETCH;
                end else begin
                    n_state = WB;
                end
            end
            WB: n_state = FETCH;
        endcase
    end


    // output combinational logic
    always_comb begin
        pc_en = 0;
        rf_we = 0;
        branch = 0;
        jal = 0;
        jalr = 0;
        alusrc_sel = 0;
        rfsrc_sel = 3'b0;
        mem_mode = 3'b0;
        alu_control = 0;
        dwe = 0;

        case (c_state)
            FETCH: pc_en = 1;
            EXECUTE: begin
                case (opcode)
                    `R_TYPE: begin
                        rf_we = 1;
                        alusrc_sel = 0;
                        alu_control = {funct7[5], funct3};
                    end
                    `I_TYPE: begin
                        rf_we      = 1;
                        alusrc_sel = 1;
                        rfsrc_sel  = 3'b0;
                        if (funct3 == 3'b101) alu_control = {funct7[5], funct3};
                        else alu_control = {1'b0, funct3};
                    end
                    `B_TYPE: begin
                        branch = 1;
                        alusrc_sel = 0;
                        alu_control = {1'b0, funct3};
                    end
                    `J_TYPE, `JL_TYPE: begin
                        rf_we = 1;
                        jal   = 1;
                        if (opcode == `JL_TYPE) jalr = 1;
                        else jalr = 0;
                        rfsrc_sel = 3'd4;
                    end
                    `UL_TYPE, `UA_TYPE: begin
                        rf_we = 1;
                        if (opcode == `UA_TYPE) rfsrc_sel = 3'd3;
                        else rfsrc_sel = 3'd2;
                    end
                    `S_TYPE, `IL_TYPE: begin
                        alusrc_sel  = 1;
                        alu_control = `ADD;
                    end
                endcase
            end
            MEM: begin
                mem_mode = funct3;
                if (opcode == `S_TYPE) dwe = 1;
                else dwe = 0;
            end
            WB: begin
                rf_we = 1;
                rfsrc_sel = 1;
            end
        endcase
    end

endmodule

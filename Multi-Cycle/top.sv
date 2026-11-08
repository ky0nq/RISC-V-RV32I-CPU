`timescale 1ns / 1ps

module top (
    input logic clk,
    input logic rst,
    output logic [15:0] led // output for implementation
);
    logic [31:0] instr_addr, instr_code, daddr, dwdata, drdata;
    logic [2:0] mem_mode;
    logic       dwe;

    // implementation logic for calculate critical path time =======================
    logic [31:0] wb_out;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) led <= 16'h0;
        else     led <= wb_out[15:0];
    end
    // =============================================================================
    
    instr_mem U_INSTR_MEM (.*);
    rv32i_cpu U_RV32I_CPU (.*);
    data_mem U_DATA_RAM (.*);
endmodule

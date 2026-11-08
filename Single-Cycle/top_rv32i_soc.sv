`timescale 1ns / 1ps

module top_rv32i_soc (
    input logic clk,
    input logic rst,
    output logic [15:0] led // implementation output
);
    logic [31:0] instr_addr, instr_code, daddr, dwdata, drdata;
    logic [2:0] mem_mode;
    logic       dwe;

    // Flip-Flop for critical path calculate
    logic [31:0] wb_out; // IL-type write back path 
    always_ff @(posedge clk or posedge rst) begin
        if (rst) led <= 16'h0;
        else     led <= wb_out[15:0];
    end
    
    instruction_mem U_INSTR_MEM (.*);
    rv32i_cpu U_RV32I_CPU (.*);
    data_mem U_DATA_RAM (.*);

endmodule

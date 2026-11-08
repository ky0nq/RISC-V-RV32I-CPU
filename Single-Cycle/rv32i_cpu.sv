`timescale 1ns / 1ps

module rv32i_cpu (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] instr_code,
    input  logic [31:0] drdata,
    output logic [31:0] instr_addr,
    output logic [ 2:0] mem_mode,
    output logic        dwe,
    output logic [31:0] daddr,
    output logic [31:0] dwdata,

    // output for implementation
    output logic [31:0] wb_out
);
    // connection control unit - datapath in cpu
    logic rf_we, branch, jalr, jal;
    logic alusrc_sel;
    logic [2:0] rfsrc_sel;
    logic [3:0] alu_control;

    control_unit U_CONTROL_UNIT (.*);
    datapath U_DATAPATH (.*);

endmodule

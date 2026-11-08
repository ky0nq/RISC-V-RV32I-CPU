`timescale 1ns / 1ps
`include "define.vh"

module data_mem (
    input  logic        clk,
    input  logic        dwe,
    input  logic [ 2:0] mem_mode,
    input  logic [31:0] daddr,
    input  logic [31:0] dwdata,
    output logic [31:0] drdata
);
    logic [31:0] data_ram  [0:63];
    logic [31:0] map_rdata;

    mem_mapper U_MEM_MAPPER (
        .mem_mode (mem_mode),
        .byte_place (daddr[1:0]),
        .map_rdata(map_rdata),
        .drdata   (drdata)
    );

    assign map_rdata = data_ram[daddr[31:2]];

    always_ff @(posedge clk) begin
        if (dwe) begin
            case (mem_mode)
                `SB: begin
                    case (daddr[1:0])
                        2'b00: data_ram[daddr[31:2]][7:0] <= dwdata[7:0];
                        2'b01: data_ram[daddr[31:2]][15:8] <= dwdata[7:0];
                        2'b10: data_ram[daddr[31:2]][23:16] <= dwdata[7:0];
                        2'b11: data_ram[daddr[31:2]][31:24] <= dwdata[7:0];
                    endcase
                end
                `SH: begin
                    case (daddr[1])
                        1'b0: data_ram[daddr[31:2]][15:0] <= dwdata[15:0];
                        1'b1: data_ram[daddr[31:2]][31:16] <= dwdata[15:0];
                    endcase
                end
                `SW: data_ram[daddr[31:2]] <= dwdata;
            endcase
        end
    end
endmodule

module mem_mapper (
    input  logic [ 2:0] mem_mode,
    input  logic [ 1:0] byte_place,  // daddr [1:0]
    input  logic [31:0] map_rdata,
    output logic [31:0] drdata
);

    // read scenario = Load
    always_comb begin
        drdata = 32'd0;
        case (mem_mode)
            `LB: 
            case (byte_place)
                2'b00: drdata = {{24{map_rdata[7]}}, map_rdata[7:0]};
                2'b01: drdata = {{24{map_rdata[15]}}, map_rdata[15:8]};
                2'b10: drdata = {{24{map_rdata[23]}}, map_rdata[23:16]};
                2'b11: drdata = {{24{map_rdata[31]}}, map_rdata[31:24]};
            endcase
            `LH:
            case (byte_place[1])
                1'b0: drdata = {{16{map_rdata[15]}}, map_rdata[15:0]};
                1'b1: drdata = {{16{map_rdata[31]}}, map_rdata[31:16]};
            endcase

            `LW: drdata = map_rdata;

            `LBU:
            case (byte_place)
                2'b00: drdata = {24'd0, map_rdata[7:0]};
                2'b01: drdata = {24'd0, map_rdata[15:8]};
                2'b10: drdata = {24'd0, map_rdata[23:16]};
                2'b11: drdata = {24'd0, map_rdata[31:24]};
            endcase
            `LHU:
            case (byte_place[1])
                1'b0: drdata = {16'd0, map_rdata[15:0]};
                1'b1: drdata = {16'd0, map_rdata[31:16]};
            endcase
        endcase
    end
endmodule

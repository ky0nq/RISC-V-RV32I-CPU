`timescale 1ns / 1ps

module tb_multi_rv32i ();

    logic clk;
    logic rst;
    top dut (.*);

    always #5 clk = ~clk;
    initial begin
        clk = 0;
        rst = 1;
        @(negedge clk);
        @(negedge clk);
        rst = 0;
        repeat (800) @(negedge clk);
        $stop;
    end
endmodule

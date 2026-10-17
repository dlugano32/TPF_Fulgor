interface bch_encoder_if
    import bch_encoder_pkg::*;
(
    input logic clk
);
    logic                 i_rst_n;
    logic                 i_valid;
    logic [K - 1 : 0]     i_msg;
    logic [N - 1 : 0]     o_cw;


    clocking cb_drv @(negedge clk);
        default input #1step output #1ps;
        output i_msg, i_valid, i_rst_n;
    endclocking

    modport DRV (clocking cb_drv, input clk);

    clocking cb_mon @(negedge clk);
        default input #1step;
        input i_rst_n, i_msg, i_valid, o_cw;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface

interface prbs31_if
    import prbs31_pkg::*;
(
    input logic clk
);
    logic                 i_rst_n;
    logic                 i_en;
    logic [ORDER - 1 : 0] i_seed;
    logic [P - 1 : 0]     o_prbs;

    clocking cb_drv @(negedge clk);
        default input #1step output #1ps;
        output i_rst_n, i_en, i_seed;
    endclocking

    modport DRV (clocking cb_drv, input clk);

    clocking cb_mon @(negedge clk);
        default input #1step;
        input i_rst_n, i_en, i_seed, o_prbs;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface

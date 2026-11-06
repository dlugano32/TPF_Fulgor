`timescale 1ps/1ps

interface tx_rx_cdc_if #(
    localparam int ORDER = 31,
    localparam int CNT_W = $clog2(7 * 113 + 1)
) (
    input logic clk_fec,
    input logic clk_dsp
);
    logic                 i_arst_n;
    logic                 i_en;
    logic [ORDER - 1 : 0] i_seed;
    logic                 o_locked;
    logic [CNT_W - 1 : 0] o_error_count;
    logic                 o_valid;
    logic [1023:0]        error_mask;
    logic                 injection_done;
    logic                 dsp_transfer;

    clocking cb_drv @(negedge clk_fec);
        default input #1step output #1ps;
        output i_en, i_seed;
    endclocking

    // Drive asynchronous reset directly, outside the clocking output driver.
    clocking cb_dsp @(negedge clk_dsp);
        default input #1step output #1ps;
        output error_mask, injection_done;
        input o_locked, dsp_transfer;
    endclocking

    modport DRV (clocking cb_drv, clocking cb_dsp, input clk_fec, output i_arst_n);

    clocking cb_mon @(negedge clk_fec);
        default input #1step;
        input i_arst_n, i_en, o_locked, o_error_count, o_valid;
        input injection_done;
    endclocking

    modport MON (clocking cb_mon, input clk_fec);

endinterface

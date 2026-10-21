interface tx_rx_top_if #(
    localparam int ORDER  = 31,
    localparam int LANES  = 7,
    localparam int N      = 127,
    localparam int K      = 113,
    localparam int LINE_W = LANES*N,
    localparam int CNT_W  = $clog2(LANES*K + 1)
) (
    input logic clk
);
    logic                             i_rst_n;
    logic                             i_en;
    logic [ORDER - 1 : 0]             i_seed;

    logic [LINE_W - 1 : 0]            tx_line;
    logic [LINE_W - 1 : 0]            error_mask;
    logic [LINE_W - 1 : 0]            channel_line;
    logic [LANES  - 1 : 0][K - 1 : 0] rx_payload;
    logic                             o_locked;
    logic [CNT_W - 1 : 0]             o_error_count;

    clocking cb_drv @(negedge clk);
        default input #1step output #1ps;
        output i_rst_n, i_en, i_seed, error_mask;
        input  o_locked;
    endclocking

    modport DRV (clocking cb_drv, input clk);

    clocking cb_mon @(negedge clk);
        default input #1step;
        input i_rst_n, i_en, error_mask, o_locked, o_error_count;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface

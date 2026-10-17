interface bch_codec_if
    import bch_decoder_pkg::*;
(
    input logic clk
);
    logic                 i_rst_n;
    logic                 i_valid;
    logic [K - 1 : 0]     i_msg;
    logic [N - 1 : 0]     i_error_mask;

    logic [N - 1 : 0]     encoder_cw;
    logic [N - 1 : 0]     decoder_rx;
    logic [N - 1 : 0]     o_err;
    logic [N - 1 : 0]     o_cw;
    logic [K - 1 : 0]     o_msg;
    logic                 o_corrected;
    logic                 o_uncorrectable;

    logic [N - 1 : 0]     encoder_cw_r0;
    logic [N - 1 : 0]     encoder_cw_r1;
    logic [N - 1 : 0]     encoder_cw_r2;
    logic [N - 1 : 0]     encoded_cw_aligned;
    logic [N - 1 : 0]     rx_r0;
    logic [N - 1 : 0]     rx_r1;
    logic [N - 1 : 0]     rx_r2;
    logic [N - 1 : 0]     rx_aligned;
    logic                 valid_r0;
    logic                 valid_r1;
    logic                 valid_r2;
    logic                 valid_r3;
    logic                 o_valid;

    // 5 latency cycles encoder + decoder
    always_ff @(posedge clk) begin
        if (!i_rst_n) begin
            encoder_cw_r0      <= '0;
            encoder_cw_r1      <= '0;
            encoder_cw_r2      <= '0;
            encoded_cw_aligned <= '0;
            rx_r0              <= '0;
            rx_r1              <= '0;
            rx_r2              <= '0;
            rx_aligned         <= '0;
            valid_r0           <= 1'b0;
            valid_r1           <= 1'b0;
            valid_r2           <= 1'b0;
            valid_r3           <= 1'b0;
            o_valid            <= 1'b0;
        end else begin
            // 4 stages decoder
            encoder_cw_r0      <= encoder_cw;
            encoder_cw_r1      <= encoder_cw_r0;
            encoder_cw_r2      <= encoder_cw_r1;
            encoded_cw_aligned <= encoder_cw_r2;

            // 4 stages decoder
            rx_r0              <= decoder_rx;
            rx_r1              <= rx_r0;
            rx_r2              <= rx_r1;
            rx_aligned         <= rx_r2;

            // 5 stages from encoder to decoder
            valid_r0           <= i_valid;
            valid_r1           <= valid_r0;
            valid_r2           <= valid_r1;
            valid_r3           <= valid_r2;
            o_valid            <= valid_r3;
        end
    end

    clocking cb_drv @(negedge clk);
        default input #1step output #1ps;
        output i_msg, i_error_mask, i_valid, i_rst_n;
    endclocking

    modport DRV (clocking cb_drv, input clk);

    clocking cb_mon @(negedge clk);
        default input #1step;
        input i_rst_n, o_valid, encoded_cw_aligned, rx_aligned;
        input o_err, o_cw, o_msg, o_corrected, o_uncorrectable;
    endclocking

    modport MON (clocking cb_mon, input clk);

endinterface

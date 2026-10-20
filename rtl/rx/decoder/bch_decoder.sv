`timescale 1ps/1ps

module bch_decoder
    import bch_decoder_pkg::*;
(
    input  logic             i_clk,
    input  logic             i_rst_n,
    input  logic             i_en,
    input  logic [N - 1 : 0] i_rx,
    output logic [N - 1 : 0] o_err,
    output logic [N - 1 : 0] o_cw,
    output logic [K - 1 : 0] o_msg,
    output logic             o_corrected,
    output logic             o_uncorrectable
);

    // =========================================================================
    // PIPE 0 START: SYNDROME CALCULATION
    // =========================================================================
    // Combinational signals
    logic [M - 1 : 0] syn1;
    logic [M - 1 : 0] syn3;

    // Stage registers
    logic [N - 1 : 0] rx_r0;
    logic [M - 1 : 0] syn1_r0;
    logic [M - 1 : 0] syn3_r0;

    bch_syndrome
    u_bch_syndrome (
        .i_rx   (i_rx),
        .o_syn1 (syn1),
        .o_syn3 (syn3)
    );

    // PIPE 0 END: STAGE REGISTER
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            rx_r0   <= '0;
            syn1_r0 <= '0;
            syn3_r0 <= '0;
        end else if (i_en) begin
            rx_r0   <= i_rx;
            syn1_r0 <= syn1;
            syn3_r0 <= syn3;
        end
    end

    // =========================================================================
    // PIPE 1 START: MU NUMERATOR AND DENOMINATOR GENERATION
    // =========================================================================
    // Combinational signals
    logic [M - 1 : 0] mu;
    logic [M - 1 : 0] log_mu;
    logic [M - 1 : 0] log_syn1;
    logic [M - 1 : 0] syn1_cubed;

    // Stage registers
    logic [N - 1 : 0] rx_r1;
    logic [M - 1 : 0] syn1_r1;
    logic [M - 1 : 0] syn3_r1;

    bch_mu_calculator
    u_bch_mu_calculator (
        .i_clk       (i_clk),
        .i_rst_n     (i_rst_n),
        .i_en        (i_en),
        .i_syn1      (syn1_r0),
        .i_syn3      (syn3_r0),
        .o_mu        (mu),
        .o_log_mu    (log_mu),
        .o_log_syn1  (log_syn1),
        .o_cube_syn1 (syn1_cubed)
    );

    // PIPE 1 END: STAGE REGISTER
    // The matching numerator and denominator registers are inside bch_mu_calculator.
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            rx_r1   <= '0;
            syn1_r1 <= '0;
            syn3_r1 <= '0;
        end else if (i_en) begin
            rx_r1   <= rx_r0;
            syn1_r1 <= syn1_r0;
            syn3_r1 <= syn3_r0;
        end
    end

    // =========================================================================
    // PIPE 2 START: MU AND OMEGA CALCULATION
    // =========================================================================
    // Combinational signals
    logic [M - 1 : 0] omega1;
    logic [M - 1 : 0] omega2;

    // Stage registers
    logic [N - 1 : 0] rx_r2;
    logic [M - 1 : 0] syn1_r2;
    logic [M - 1 : 0] syn3_r2;
    logic [M - 1 : 0] omega1_r2;
    logic [M - 1 : 0] omega2_r2;
    logic [M - 1 : 0] log_mu_r2;
    logic [M - 1 : 0] log_syn1_r2;
    logic [M - 1 : 0] syn1_cubed_r2;

    bch_omega_calculator
    u_bch_omega_calculator (
        .i_mu     (mu),
        .o_omega1 (omega1),
        .o_omega2 (omega2)
    );

    // PIPE 2 END: STAGE REGISTER
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            rx_r2         <= '0;
            syn1_r2       <= '0;
            syn3_r2       <= '0;
            omega1_r2     <= '0;
            omega2_r2     <= '0;
            log_mu_r2     <= '0;
            log_syn1_r2   <= '0;
            syn1_cubed_r2 <= '0;
        end else if (i_en) begin
            rx_r2         <= rx_r1;
            syn1_r2       <= syn1_r1;
            syn3_r2       <= syn3_r1;
            omega1_r2     <= omega1;
            omega2_r2     <= omega2;
            log_mu_r2     <= log_mu;
            log_syn1_r2   <= log_syn1;
            syn1_cubed_r2 <= syn1_cubed;
        end
    end

    // =========================================================================
    // PIPE 3 START: ERROR LOCATION AND CORRECTION
    // =========================================================================
    // Combinational signals
    logic [M - 1 : 0] single_err_pos;
    logic [M - 1 : 0] double_err_pos1;
    logic [M - 1 : 0] double_err_pos2;

    logic [M - 1 : 0] log_root1;
    logic [M - 1 : 0] log_root2;

    logic [N - 1 : 0] single_err_mask;
    logic [N - 1 : 0] double_err_mask;
    logic [N - 1 : 0] sel_err_mask;
    logic [N - 1 : 0] corrected_cw;
    logic             single_err;
    logic             double_err;
    logic             corrected;
    logic             uncorrectable;

    // Double-error locations
    bch_root_calculator
    u_bch_root1_calculator (
        .i_omega    (omega1_r2),
        .i_log_mu   (log_mu_r2),
        .i_log_syn1 (log_syn1_r2),
        .o_log_root (log_root1)
    );

    bch_root_calculator
    u_bch_root2_calculator (
        .i_omega    (omega2_r2),
        .i_log_mu   (log_mu_r2),
        .i_log_syn1 (log_syn1_r2),
        .o_log_root (log_root2)
    );

    // Error positions and masks
    assign single_err_pos = log_syn1_r2;

    assign double_err_pos1 = (log_root1 == '0) ? 7'd0 : (7'd127 - log_root1);

    assign double_err_pos2 = (log_root2 == '0) ? 7'd0 : (7'd127 - log_root2);

    assign single_err_mask =  127'd1 << single_err_pos;
    assign double_err_mask = (127'd1 << double_err_pos1) | (127'd1 << double_err_pos2);

    // Error classification
    assign single_err = (syn1_r2 != '0) && (syn1_cubed_r2 == syn3_r2);

    // For GF(2^7) with p(x) = x^7 + x^3 + 1, Tr(mu) = mu[0] = omega1[0].
    assign double_err = (syn1_r2 != '0) && (syn1_cubed_r2 != syn3_r2) && (omega1_r2[0] == 1'b0);

    assign uncorrectable = ((syn1_r2 == '0) && (syn3_r2 != '0)) ||
                           ((syn1_r2 != '0) && (syn1_cubed_r2 != syn3_r2) && (omega1_r2[0] == 1'b1));

    // Error correction. Uncorrectable words pass-through.
    assign sel_err_mask = single_err ? single_err_mask :
                          double_err ? double_err_mask :
                                       '0;

    assign corrected_cw = rx_r2 ^ sel_err_mask;
    assign corrected    = single_err || double_err;

    // =========================================================================
    // PIPE 3 END: OUTPUT REGISTER
    // =========================================================================
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_err           <= '0;
            o_cw            <= '0;
            o_msg           <= '0;
            o_corrected     <= 1'b0;
            o_uncorrectable <= 1'b0;
        end else if (i_en) begin
            o_err           <= sel_err_mask;
            o_cw            <= corrected_cw;
            o_msg           <= corrected_cw[N - 1 -: K];
            o_corrected     <= corrected;
            o_uncorrectable <= uncorrectable;
        end
    end

endmodule

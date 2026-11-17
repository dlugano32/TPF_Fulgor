`timescale 1ps/1ps

module bch_mu_calculator #(
    localparam int M = 7
) (
    input  logic                 i_clk,
    input  logic                 i_rst_n,
    input  logic                 i_en,
    input  logic [M - 1 : 0]     i_syn1,
    input  logic [M - 1 : 0]     i_syn3,
    output logic [M - 1 : 0]     o_mu,
    output logic [M - 1 : 0]     o_log_mu,
    output logic [M - 1 : 0]     o_log_syn1,
    output logic [M - 1 : 0]     o_cube_syn1
);
    // Computes mu = (S1^3 + S3) / S1^3.

    // =========================================================================
    // PIPE 1: MU NUMERATOR AND DENOMINATOR GENERATION
    // =========================================================================
    logic [M - 1 : 0] log_syn1;
    logic [M + 1 : 0] triple_log_syn1;

    logic [M - 1 : 0] syn1_cubed;
    logic [M - 1 : 0] log_syn1_cubed;

    logic [M - 1 : 0] num;
    logic [M - 1 : 0] num_r1;
    logic [M - 1 : 0] log_syn1_cubed_r1;
    logic [M - 1 : 0] log_syn1_r1;
    logic [M - 1 : 0] syn1_cubed_r1;

    logic [M - 1 : 0] log_num;

    logic [M - 1 : 0] mu;
    logic [M - 1 : 0] log_mu;
    logic [M     : 0] log_mu_diff;

    // log(S1)
    gf127_log_lut
    u_log_syn1_lut (
        .i_element   (i_syn1),
        .o_logarithm (log_syn1)
    );

    // Logarithmic denominator, computed in parallel with the direct cube.
    assign triple_log_syn1 = 3 * log_syn1;

    assign log_syn1_cubed = (triple_log_syn1 >= 9'd254) ? (triple_log_syn1 - 9'd254) :
                            (triple_log_syn1 >= 9'd127) ? (triple_log_syn1 - 9'd127) :
                                                           triple_log_syn1;

    gf127_cube_lut
    u_cube_syn1_lut (
        .i_element (i_syn1),
        .o_cube    (syn1_cubed)
    );

    // Numerator: S1^3 + S3
    assign num = syn1_cubed ^ i_syn3;

    // PIPE 1 END: NUMERATOR AND DENOMINATOR REGISTER
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            num_r1              <= '0;
            log_syn1_cubed_r1   <= '0;
            log_syn1_r1         <= '0;
            syn1_cubed_r1       <= '0;
        end else if (i_en) begin
            num_r1              <= num;
            log_syn1_cubed_r1   <= log_syn1_cubed;
            log_syn1_r1         <= log_syn1;
            syn1_cubed_r1       <= syn1_cubed;
        end
    end

    // =========================================================================
    // PIPE 2: LOGARITHMIC DIVISION
    // =========================================================================
    gf127_log_lut
    u_log_num_lut (
        .i_element   (num_r1),
        .o_logarithm (log_num)
    );

    // Module substraction for division
    // log(mu) = log(S1^3 + S1) / S1^3
    // Correct the wrapped difference by -1 when the subtraction borrows.
    assign log_mu_diff = {1'b0, log_num} - {1'b0, log_syn1_cubed_r1};
    assign log_mu = log_mu_diff[M] ? (log_mu_diff[M - 1 : 0] - 7'd1)
                                   :  log_mu_diff[M - 1 : 0];

    gf127_exp_lut
    u_exp_mu_lut (
        .i_exponent (log_mu),
        .o_element  (mu)
    );

    assign o_mu        = mu;
    assign o_log_mu    = log_mu;
    assign o_log_syn1  = log_syn1_r1;
    assign o_cube_syn1 = syn1_cubed_r1;

endmodule

`timescale 1ps/1ps

module bch_root_calculator #(
    localparam int M = 7
) (
    input  logic [M - 1 : 0] i_omega,
    input  logic [M - 1 : 0] i_log_mu,
    input  logic [M - 1 : 0] i_log_syn1,

    output logic [M - 1 : 0] o_log_root
);
    logic [M - 1 : 0] log_omega;
    logic [M     : 0] log_den_sum;
    logic [M - 1 : 0] log_den;
    logic [M     : 0] log_root_diff;

    gf127_log_lut
    u_log_omega_lut (
        .i_element   (i_omega),
        .o_logarithm (log_omega)
    );

    // Denominator: mu * S1
    assign log_den_sum = {1'b0, i_log_mu} + {1'b0, i_log_syn1};

    assign log_den = (log_den_sum >= 8'd127) ? (log_den_sum - 8'd127) : 
                                                log_den_sum;

    // Module substraction for division
    // log(root) = log(omega) - log(mu * S1) mod 127
    // Correct the wrapped difference by -1 when the subtraction borrows.
    assign log_root_diff = {1'b0, log_omega} - {1'b0, log_den};
    assign o_log_root = log_root_diff[M] ? (log_root_diff[M - 1 : 0] - 7'd1)
                                         :  log_root_diff[M - 1 : 0];
endmodule

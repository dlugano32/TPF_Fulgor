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

    gf127_log_lut
    u_log_omega_lut (
        .i_element   (i_omega),
        .o_logarithm (log_omega)
    );

    // Denominator: mu * S1
    assign log_den_sum = {1'b0, i_log_mu} + {1'b0, i_log_syn1};

    assign log_den = (log_den_sum >= 8'd127) ? (log_den_sum - 8'd127) : 
                                                log_den_sum;

    // log(root) = log(omega) - log(mu * S1) mod 127
    assign o_log_root = (log_omega >= log_den) ? (log_omega - log_den) : 
                                                 (7'd127 - (log_den - log_omega));
endmodule

`timescale 1ps/1ps

module bch_omega_calculator #(
    localparam int M = 7
) (
    input  logic [M - 1 : 0] i_mu,
    output logic [M - 1 : 0] o_omega1,
    output logic [M - 1 : 0] o_omega2
);

    assign o_omega1[0] = i_mu[0];
    assign o_omega1[1] = i_mu[2] ^ i_mu[3] ^ i_mu[4] ^ i_mu[6];
    assign o_omega1[2] = i_mu[3] ^ i_mu[4] ^ i_mu[6];
    assign o_omega1[3] = i_mu[5] ^ i_mu[6];
    assign o_omega1[4] = i_mu[1] ^ i_mu[2] ^ i_mu[4];
    assign o_omega1[5] = i_mu[3] ^ i_mu[5] ^ i_mu[6];
    assign o_omega1[6] = i_mu[3] ^ i_mu[6];

    assign o_omega2 = o_omega1 ^ 7'h01;

endmodule
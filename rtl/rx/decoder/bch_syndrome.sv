`timescale 1ps/1ps

module bch_syndrome
    import bch_decoder_pkg::*;
(
    input  logic [N - 1 : 0] i_rx,
    output logic [M - 1 : 0] o_syn1,
    output logic [M - 1 : 0] o_syn3
);

    logic [R - 1 : 0] syndrome;

    bch_mult_m
    u_bch_mult_m (
        .i_vec (i_rx),
        .o_vec (syndrome)
    );

    assign o_syn1 = syndrome[0 +: M];
    assign o_syn3 = syndrome[M +: M];
endmodule
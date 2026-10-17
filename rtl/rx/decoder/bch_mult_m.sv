`timescale 1ps/1ps

module bch_mult_m 
    import bch_decoder_pkg::*;
(
    input  logic [N - 1 : 0] i_vec,
    output logic [R - 1 : 0] o_vec
);

    genvar i;
    generate
        for (i = 0; i < R; i++) begin : gen_mult
            assign o_vec[i] = ^(i_vec & M_T[i]);
        end
    endgenerate
    
endmodule
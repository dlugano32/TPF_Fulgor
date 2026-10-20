`timescale 1ps/1ps

module prbs31_mult_b
    import prbs31_pkg::*;
(
    input  logic [ORDER - 1 : 0] i_state,
    output logic [P     - 1 : 0] o_prbs
);

    genvar i;
    generate
        for (i = 0; i < P; i++) begin : gen_mult
            assign o_prbs[i] = ^(i_state & B[i]);
        end
    endgenerate

endmodule
`timescale 1ps/1ps

module prbs31_mult_a
    import prbs31_pkg::*;
(
    input  logic [ORDER - 1 : 0] i_state,
    output logic [ORDER - 1 : 0] o_state_next 
);

    genvar i;
    generate
        for (i = 0; i < ORDER; i++) begin : gen_mult
            assign o_state_next[i] = ^(i_state & A[i]);
        end
    endgenerate

endmodule
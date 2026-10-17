`timescale 1ps/1ps

module gf127_cube#(
    localparam int M = 7
) (
    input  logic [M - 1 : 0] i_element,
    output logic [M - 1 : 0] o_cube
);

    logic [M - 1 : 0] element_log;
    logic [M + 1 : 0] triple_log;
    logic [M - 1 : 0] cube_exp;
    logic [M - 1 : 0] cube;


    gf127_log_lut
    u_cube_log_lut (
        .i_element(i_element),
        .o_logarithm(element_log)
    );

    assign triple_log = 3 * element_log;


    assign cube_exp = (triple_log >= 9'd254) ? triple_log - 9'd254 :
                      (triple_log >= 9'd127) ? triple_log - 9'd127 :
                                               triple_log;

    gf127_exp_lut 
    u_cube_exp_lut (
        .i_exponent (cube_exp),
        .o_element  (cube)
    );

    assign o_cube = (i_element == '0) ? '0 : cube;

endmodule
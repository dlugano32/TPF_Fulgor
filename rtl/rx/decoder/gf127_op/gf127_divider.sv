`timescale 1ps/1ps

module gf127_divider #(
    localparam int M = 7
) (
    input  logic [M - 1 : 0] i_num,
    input  logic [M - 1 : 0] i_den,
    output logic [M - 1 : 0] o_quo,
    output logic             o_div_by_zero
);
    logic [M - 1 : 0] log_num;
    logic [M - 1 : 0] log_den;
    logic [M - 1 : 0] log_quo;
    logic [M - 1 : 0] quo;

    gf127_log_lut
    u_num_log_lut (
        .i_element   (i_num),
        .o_logarithm (log_num)
    );

    gf127_log_lut
    u_den_log_lut (
        .i_element   (i_den),
        .o_logarithm (log_den)
    );

    assign log_quo = (log_num >= log_den) ? log_num - log_den : 
                                            (7'd127 - (log_den - log_num));

    gf127_exp_lut
    u_quo_exp_lut (
        .i_exponent (log_quo),
        .o_element  (quo)
    );

    assign o_quo         = (i_num == '0 || i_den == '0) ? '0 : quo;
    assign o_div_by_zero = ~|(i_den);

endmodule

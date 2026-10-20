`timescale 1ps/1ps

module bch_encoder
    import bch_encoder_pkg::*;
(
    input  logic i_clk,
    input  logic i_rst_n,
    input  logic i_en,
    input  logic [K - 1 : 0] i_msg,
    output logic [N - 1 : 0] o_cw
);
    logic [R - 1 : 0] parity;

    bch_mult_p
    u_bch_mult_p (
        .i_vec (i_msg),
        .o_vec (parity)
    );

    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_cw <= '0;
        end else if (i_en) begin
            o_cw <= {i_msg, parity};
        end
    end
endmodule

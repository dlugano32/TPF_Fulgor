`timescale 1ps/1ps

module tx_top #(
    localparam int ORDER = 31,
    localparam int LANES = 7,
    localparam int N = 127,
    localparam int K = 113
) (
    input  logic                             i_clk,
    input  logic                             i_rst_n,
    input  logic                             i_en,
    input  logic [ORDER - 1 : 0]             i_seed,

    output logic [LANES - 1 : 0] [N - 1 : 0] o_payload
);

    logic [LANES - 1 : 0] [K - 1 : 0] data;

    prbs31 u_prbs31 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_seed(i_seed),
        .o_prbs(data)
    );

    genvar i;
    generate
        for(i=0; i < LANES; i++) begin
            bch_encoder u_bch_encoder (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_en),
                .i_msg(data[i]),
                .o_cw(o_payload[i])
            );
        end
    endgenerate

endmodule

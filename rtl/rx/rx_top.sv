`timescale 1ps/1ps

module rx_top #(
    localparam int ORDER = 31,
    localparam int LANES = 7,
    localparam int N = 127,
    localparam int K = 113,
    localparam int CNT_W = $clog2(LANES*K + 1)
) (
    input  logic                             i_clk,
    input  logic                             i_rst_n,
    input  logic                             i_en,
    input  logic [LANES - 1 : 0] [N - 1 : 0] i_payload,

    output logic [LANES - 1 : 0] [K - 1 : 0] o_data,
    output logic                             o_locked,
    output logic [CNT_W - 1 : 0]             o_error_count
);

    logic [LANES - 1 : 0] [K - 1 : 0] data;

    genvar i;
    generate
        for(i=0; i < LANES; i++) begin
            bch_decoder u_bch_decoder (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_en),
                .i_rx(i_payload[i]),
                .o_msg(data[i])
            );
        end
    endgenerate

    prbs31_checker u_prbs31_checker (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_data(data),
        .o_locked(o_locked),
        .o_error_count(o_error_count)
    );

    assign o_data = data;

endmodule

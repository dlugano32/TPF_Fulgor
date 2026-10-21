`timescale 1ps/1ps

module tx_top #(
    localparam int ORDER = 31,
    localparam int LANES = 7,
    localparam int CW_W = 127,
    localparam int PAY_W = 113,
    localparam int LINE_W = LANES * CW_W
) (
    input  logic                  i_clk,
    input  logic                  i_rst_n,
    input  logic                  i_en,
    input  logic [ORDER  - 1 : 0] i_seed,
    output logic [LINE_W - 1 : 0] o_line
);

    logic [LANES  - 1 : 0][PAY_W - 1 : 0] payload;
    logic [LANES  - 1 : 0][CW_W  - 1 : 0] codewords;
    logic [LINE_W - 1 : 0]                permuted;
    logic [LINE_W - 1 : 0]                interleaved;

    prbs31 u_prbs31 (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_seed(i_seed),
        .o_prbs(payload)
    );

    genvar i;
    generate
        for(i=0; i < LANES; i++) begin
            bch_encoder u_bch_encoder (
                .i_clk(i_clk),
                .i_rst_n(i_rst_n),
                .i_en(i_en),
                .i_msg(payload[i]),
                .o_cw(codewords[i])
            );
        end
    endgenerate

    lane_permuter #(
        .LANES(LANES),
        .CW_W (CW_W)
    ) u_lane_permuter (
        .i_codewords(codewords),
        .o_line(permuted)
    );

    conv_interleaver #(
        .D(1),
        .B(8),
        .LINE_W(LINE_W)
    ) u_conv_interleaver (
        .i_clk(i_clk),
        .i_rst_n(i_rst_n),
        .i_en(i_en),
        .i_line(permuted),
        .o_line(interleaved)
    );

    assign o_line = interleaved;
endmodule

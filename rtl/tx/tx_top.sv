`timescale 1ps/1ps

module tx_top #(
    localparam int unsigned PRBS_ORDER = 31,
    localparam int unsigned DSP_W = 1016
) (
    input  logic                          i_clk_fec,
    input  logic                          i_clk_dsp,
    input  logic                          i_arst_n,
    input  logic                          i_en,
    input  logic [PRBS_ORDER - 1 : 0]     i_seed,

    output logic [DSP_W - 1 : 0]          o_dsp_line,
    output logic                          o_dsp_valid
);
    localparam int unsigned LANES = 7;
    localparam int unsigned CW_W = 127;
    localparam int unsigned PAY_W = 113;
    localparam int unsigned FEC_W = LANES * CW_W;
    localparam int unsigned RESET_SYNC_STAGES = 2;

    logic fec_rst_n;
    logic dsp_rst_n;

    logic [LANES - 1 : 0][PAY_W - 1 : 0] payload;
    logic [LANES - 1 : 0][CW_W  - 1 : 0] codewords;
    logic [LANES - 1 : 0] codewords_valid;
    logic fec_line_valid;
    logic [FEC_W - 1 : 0] permuted_line;
    logic [FEC_W - 1 : 0] interleaved_line;

    sync_rst_n #(
        .PIPE(RESET_SYNC_STAGES)
    ) u_sync_rst_n_fec (
        .i_clk(i_clk_fec),
        .i_arst_n(i_arst_n),
        .o_rst_n(fec_rst_n)
    );

    sync_rst_n #(
        .PIPE(RESET_SYNC_STAGES)
    ) u_sync_rst_n_dsp (
        .i_clk(i_clk_dsp),
        .i_arst_n(i_arst_n),
        .o_rst_n(dsp_rst_n)
    );

    prbs31 u_prbs31 (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(i_en),
        .i_seed(i_seed),
        .o_prbs(payload)
    );

    generate
        for (genvar lane = 0; lane < LANES; lane++) begin : gen_bch_encoder
            bch_encoder u_bch_encoder (
                .i_clk(i_clk_fec),
                .i_rst_n(fec_rst_n),
                .i_en(i_en),
                .i_msg(payload[lane]),
                .o_cw(codewords[lane]),
                .o_valid(codewords_valid[lane])
            );
        end
    endgenerate

    // All lanes accept the same transaction.
    assign fec_line_valid = &codewords_valid;

    lane_permuter #(
        .LANES(LANES),
        .CW_W(CW_W)
    ) u_lane_permuter (
        .i_codewords(codewords),
        .o_line(permuted_line)
    );

    conv_interleaver #(
        .D(1),
        .B(8),
        .LINE_W(FEC_W)
    ) u_conv_interleaver (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(fec_line_valid),
        .i_line(permuted_line),
        .o_line(interleaved_line)
    );

    gearbox_cdc #(
        .PAR_IN(LANES),
        .PAR_OUT(8),
        .DEPTH(112),
        .DATA_T(logic [CW_W  - 1 : 0])
    ) u_tx_gearbox_cdc(
        .i_wr_clk(i_clk_fec),
        .i_rd_clk(i_clk_dsp),
        .i_wr_rst_n(fec_rst_n),
        .i_rd_rst_n(dsp_rst_n),
        .i_wr_en(fec_line_valid),
        .i_data(interleaved_line),
        .o_data(o_dsp_line),
        .o_valid(o_dsp_valid)
    );

endmodule

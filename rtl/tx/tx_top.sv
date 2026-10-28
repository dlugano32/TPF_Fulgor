`timescale 1ps/1ps

module tx_top #(
    localparam int unsigned PRBS_ORDER = 31,
    localparam int unsigned DSP_W = 1024,
    localparam int unsigned FIFO_DEPTH = 8
) (
    input  wire logic                          i_clk_fec,
    input  wire logic                          i_clk_dsp,
    input  wire logic                          i_arst_n,
    input  wire logic                          i_en,
    input  wire logic [PRBS_ORDER - 1 : 0]     i_seed,

    // DSP-domain FIFO interface: consume o_line when !o_dsp_empty.
    input  wire logic                          i_dsp_rd_en,
    output wire logic [DSP_W - 1 : 0]          o_line,
    output wire logic                          o_dsp_empty,
    output wire logic [$clog2(FIFO_DEPTH) : 0] o_dsp_rd_level,

    // Write-domain status, for overflow monitoring in the FEC domain.
    output wire logic                          o_fifo_full
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

    // DSP-width words, still generated in the FEC clock domain.
    logic [DSP_W - 1 : 0] gearbox_data;
    logic gearbox_valid;

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

    gearbox_widen #(
        .BITS_IN(FEC_W),
        .BITS_OUT(DSP_W)
    ) u_gearbox_widen (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(fec_line_valid),
        .i_data(interleaved_line),
        .o_data(gearbox_data),
        .o_valid(gearbox_valid)
    );

    async_fifo #(
        .WIDTH(DSP_W),
        .DEPTH(FIFO_DEPTH)
    ) u_tx_fifo (
        .i_wr_clk(i_clk_fec),
        .i_rd_clk(i_clk_dsp),
        .i_wr_rst_n(fec_rst_n),
        .i_rd_rst_n(dsp_rst_n),
        .i_wr_en(gearbox_valid),
        .i_rd_en(i_dsp_rd_en),
        .i_data(gearbox_data),
        .o_data(o_line),
        .o_empty(o_dsp_empty),
        .o_full(o_fifo_full),
        .o_rd_level(o_dsp_rd_level)
    );
endmodule

`default_nettype wire

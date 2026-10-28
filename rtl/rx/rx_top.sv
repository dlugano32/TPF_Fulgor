`timescale 1ps/1ps

module rx_top #(
    localparam int unsigned LANES = 7,
    localparam int unsigned PAY_W = 113,
    localparam int unsigned DSP_W = 1024,
    localparam int unsigned CNT_W = $clog2(LANES * PAY_W + 1)
) (
    input  wire logic                                i_clk_fec,
    input  wire logic                                i_clk_dsp,
    input  wire logic                                i_arst_n,
    input  wire logic                                i_en,

    // DSP-domain FIFO interface: accept i_dsp_line when i_dsp_wr_en && !o_dsp_full.
    input  wire logic [DSP_W - 1 : 0]                i_dsp_line,
    input  wire logic                                i_dsp_wr_en,
    output wire logic                                o_dsp_full,

    output wire logic [LANES - 1 : 0][PAY_W - 1 : 0] o_payload,
    output wire logic                                o_locked,
    output wire logic [CNT_W - 1 : 0]                o_error_count,
    output wire logic                                o_valid
);
    localparam int unsigned CW_W = 127;
    localparam int unsigned FEC_W = LANES * CW_W;
    localparam int unsigned FIFO_DEPTH = 8;
    localparam int unsigned FIFO_LEVEL_W = $clog2(FIFO_DEPTH) + 1;
    localparam int unsigned START_LEVEL = 2;
    localparam int unsigned RESET_SYNC_STAGES = 2;

    logic fec_rst_n;
    logic dsp_rst_n;

    logic [LANES - 1 : 0][PAY_W - 1 : 0] payload;
    logic [LANES - 1 : 0][CW_W  - 1 : 0] codewords;
    logic [LANES - 1 : 0] payload_valid;
    logic decoded_line_valid;
    logic [FEC_W - 1 : 0] interleaved_line;
    logic [FEC_W - 1 : 0] deinterleaved_line;

    // DSP-width FWFT head, consumed in the FEC clock domain.
    logic [DSP_W - 1 : 0] fifo_data;
    logic [FIFO_LEVEL_W - 1 : 0] fifo_rd_level;
    logic fifo_rd_en;
    logic fifo_started;
    logic gearbox_en;
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

    async_fifo #(
        .WIDTH(DSP_W),
        .DEPTH(FIFO_DEPTH)
    ) u_rx_fifo (
        .i_wr_clk(i_clk_dsp),
        .i_rd_clk(i_clk_fec),
        .i_wr_rst_n(dsp_rst_n),
        .i_rd_rst_n(fec_rst_n),
        .i_wr_en(i_dsp_wr_en),
        .i_rd_en(fifo_rd_en),
        .i_data(i_dsp_line),
        .o_data(fifo_data),
        .o_empty(),
        .o_full(o_dsp_full),
        .o_rd_level(fifo_rd_level)
    );

    always_ff @(posedge i_clk_fec) begin
        if (!fec_rst_n)
            fifo_started <= 1'b0;
        else if (i_en && fifo_rd_level >= FIFO_LEVEL_W'(START_LEVEL))
            fifo_started <= 1'b1;
    end

    assign gearbox_en = i_en
                     && (fifo_started || fifo_rd_level >= FIFO_LEVEL_W'(START_LEVEL));

    gearbox_narrow #(
        .BITS_IN(DSP_W),
        .BITS_OUT(FEC_W)
    ) u_gearbox_narrow (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(gearbox_en),
        .i_data(fifo_data),
        .o_data(interleaved_line),
        .o_valid(gearbox_valid),
        .o_rd_en(fifo_rd_en)
    );

    conv_deinterleaver #(
        .D(1),
        .B(8),
        .LINE_W(FEC_W)
    ) u_conv_deinterleaver (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(gearbox_valid),
        .i_line(interleaved_line),
        .o_line(deinterleaved_line)
    );

    lane_depermuter #(
        .LANES(LANES),
        .CW_W(CW_W)
    ) u_lane_depermuter (
        .i_line(deinterleaved_line),
        .o_codewords(codewords)
    );

    generate
        for (genvar lane = 0; lane < LANES; lane++) begin : gen_bch_decoder
            bch_decoder u_bch_decoder (
                .i_clk(i_clk_fec),
                .i_rst_n(fec_rst_n),
                .i_en(gearbox_valid),
                .i_rx(codewords[lane]),
                .o_err(),
                .o_cw(),
                .o_msg(payload[lane]),
                .o_corrected(),
                .o_uncorrectable(),
                .o_valid(payload_valid[lane])
            );
        end
    endgenerate

    assign decoded_line_valid = &payload_valid;

    prbs31_checker u_prbs31_checker (
        .i_clk(i_clk_fec),
        .i_rst_n(fec_rst_n),
        .i_en(decoded_line_valid),
        .i_data(payload),
        .o_locked(o_locked),
        .o_error_count(o_error_count),
        .o_valid(o_valid)
    );

    assign o_payload = payload;

endmodule

`default_nettype wire

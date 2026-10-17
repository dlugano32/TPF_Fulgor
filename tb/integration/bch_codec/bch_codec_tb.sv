`timescale 1ps/1ps

module bch_codec_tb;

    import bch_codec_tb_pkg::*;
    import bch_decoder_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    bch_codec_if vif (clk);

    logic [N - 1 : 0] error_mask_r;

    always_ff @(posedge clk) begin
        if (!vif.i_rst_n)
            error_mask_r <= '0;
        else
            error_mask_r <= vif.i_error_mask;
    end

    // Error injection
    assign vif.decoder_rx = vif.encoder_cw ^ error_mask_r;

    bch_encoder u_bch_encoder (
        .i_clk   (clk),
        .i_rst_n (vif.i_rst_n),
        .i_msg   (vif.i_msg),
        .o_cw    (vif.encoder_cw)
    );

    bch_decoder u_bch_decoder (
        .i_clk           (clk),
        .i_rst_n         (vif.i_rst_n),
        .i_rx            (vif.decoder_rx),
        .o_err           (vif.o_err),
        .o_cw            (vif.o_cw),
        .o_msg           (vif.o_msg),
        .o_corrected     (vif.o_corrected),
        .o_uncorrectable (vif.o_uncorrectable)
    );

    bch_codec_program u_tb (vif);

endmodule

program automatic bch_codec_program (bch_codec_if vif);

    import bch_decoder_pkg::*;
    import bch_codec_tb_pkg::*;

    bch_codec_env env;

    initial begin
        $display("");
        $display("=== BCH codec integration simulation started ===");

        env = new(vif);
        env.run();

        $display("=== BCH codec integration simulation finished ===");
        $display("");
        $finish;
    end

endprogram

`timescale 1ps/1ps

module bch_decoder_tb;

    import bch_decoder_pkg::*;
    import bch_decoder_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    bch_decoder_if vif (clk);

    bch_decoder u_bch_decoder (
        .i_clk           (clk),
        .i_rst_n         (vif.i_rst_n),
        .i_rx            (vif.i_rx),
        .o_err           (vif.o_err),
        .o_cw            (vif.o_cw),
        .o_msg           (vif.o_msg),
        .o_corrected     (vif.o_corrected),
        .o_uncorrectable (vif.o_uncorrectable)
    );

    bch_decoder_program u_tb (vif);

endmodule

program automatic bch_decoder_program (bch_decoder_if vif);

    import bch_decoder_tb_pkg::*;

    bch_decoder_env env;

    initial begin
        $display("");
        $display("=== BCH decoder simulation started ===");

        env = new(vif);
        env.run();

        $display("=== BCH decoder simulation finished ===");
        $display("");
        $finish;
    end

endprogram

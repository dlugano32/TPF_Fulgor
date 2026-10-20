`timescale 1ps/1ps

module bch_encoder_tb;

    import bch_encoder_pkg::*;
    import bch_encoder_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    bch_encoder_if vif (clk);

    bch_encoder u_bch_encoder (
        .i_clk   (clk),
        .i_rst_n (vif.i_rst_n),
        .i_en    (1'b1),
        .i_msg    (vif.i_msg),
        .o_cw     (vif.o_cw)
    );

    bch_encoder_program u_tb (vif);

endmodule

program automatic bch_encoder_program (bch_encoder_if vif);

    import bch_encoder_tb_pkg::*;

    bch_encoder_env env;

    initial begin
        $display("");
        $display("=== BCH encoder simulation started ===");

        env = new(vif);
        env.run();

        $display("=== BCH encoder simulation finished ===");
        $display("");
        $finish;
    end

endprogram

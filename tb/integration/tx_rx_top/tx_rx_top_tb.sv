`timescale 1ps/1ps

module tx_rx_top_tb;

    import tx_rx_top_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    tx_rx_top_if vif (clk);

    tx_top u_tx_top (
        .i_clk     (clk),
        .i_rst_n   (vif.i_rst_n),
        .i_en      (vif.i_en),
        .i_seed    (vif.i_seed),
        .o_payload (vif.tx_payload)
    );

    rx_top u_rx_top (
        .i_clk         (clk),
        .i_rst_n       (vif.i_rst_n),
        .i_en          (vif.i_en),
        .i_payload     (vif.tx_payload),
        .o_data        (vif.rx_data),
        .o_locked      (vif.o_locked),
        .o_error_count (vif.o_error_count)
    );

    tx_rx_top_program u_tb (vif);

endmodule

program automatic tx_rx_top_program (tx_rx_top_if vif);

    import tx_rx_top_tb_pkg::*;

    tx_rx_top_env env;

    initial begin
        $display("");
        $display("=== TX/RX top simulation started ===");

        env = new(vif);
        env.run();

        $display("=== TX/RX top simulation finished ===");
        $display("");
        $finish;
    end

endprogram

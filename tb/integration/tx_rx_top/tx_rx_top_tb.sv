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
        .o_line    (vif.tx_line)
    );

    assign vif.channel_line = vif.tx_line ^ vif.error_mask;

    rx_top u_rx_top (
        .i_clk         (clk),
        .i_rst_n       (vif.i_rst_n),
        .i_en          (vif.i_en),
        .i_line        (vif.channel_line),
        .o_payload     (vif.rx_payload),
        .o_locked      (vif.o_locked),
        .o_error_count (vif.o_error_count)
    );

    tx_rx_top_program u_tb (vif);

endmodule

program automatic tx_rx_top_program (tx_rx_top_if vif);

    import tx_rx_top_tb_pkg::*;

    tx_rx_top_env env;

    initial begin
        string test_mode_arg;
        test_mode_e test_mode;

        if (!$value$plusargs("TEST_MODE=%s", test_mode_arg)) begin
            test_mode = CLEAN_TEST;
        end else begin
            case (test_mode_arg)
                "CLEAN", "clean": test_mode = CLEAN_TEST;
                "BURST", "burst": test_mode = BURST_TEST;
                default: $fatal(1, "Unknown TEST_MODE=%s. Use CLEAN or BURST", test_mode_arg);
            endcase
        end

        $display("");
        $display("=== TX/RX top simulation started ===");

        env = new(vif, test_mode);
        env.run();

        $display("=== TX/RX top simulation finished ===");
        $display("");
        $finish;
    end

endprogram

`timescale 1ps/1ps

module tx_rx_cdc_tb;

    // Integer half-periods preserve 889*f_FEC = 1024*f_DSP exactly at 1 ps.
    localparam time FEC_PERIOD = 2 * 889ps;
    localparam time DSP_PERIOD = 2 * 1024ps;
    localparam time DSP_PHASE = 1ps;

    logic clk_fec = 1'b0;
    logic clk_dsp = 1'b0;
    always #(FEC_PERIOD / 2) clk_fec = ~clk_fec;

    initial begin
    #(DSP_PHASE);
    forever #(DSP_PERIOD / 2) clk_dsp = ~clk_dsp;
    end

    tx_rx_cdc_if vif (clk_fec, clk_dsp);

    logic [1023:0] tx_dsp_line;
    logic tx_dsp_valid;
    logic tx_dsp_empty;
    logic rx_dsp_full;
    logic [1023:0] channel_line;

    tx_top u_tx_top (
        .i_clk_fec      (clk_fec),
        .i_clk_dsp      (clk_dsp),
        .i_arst_n       (vif.i_arst_n),
        .i_en           (vif.i_en),
        .i_seed         (vif.i_seed),
        .o_dsp_line     (tx_dsp_line),
        .o_dsp_valid    (tx_dsp_valid),
        .o_dsp_empty    (tx_dsp_empty)
    );

    assign vif.dsp_transfer = tx_dsp_valid;
    assign channel_line = tx_dsp_line ^ vif.error_mask;

    rx_top u_rx_top (
        .i_clk_fec     (clk_fec),
        .i_clk_dsp     (clk_dsp),
        .i_arst_n      (vif.i_arst_n),
        .i_en          (vif.i_en),
        .i_dsp_line    (channel_line),
        .i_dsp_wr_en   (tx_dsp_valid),
        .o_dsp_full    (rx_dsp_full),
        .o_locked      (vif.o_locked),
        .o_error_count (vif.o_error_count),
        .o_valid       (vif.o_valid)
    );

    always @(posedge clk_dsp) begin
        if (tx_dsp_valid) begin
            if (tx_dsp_empty !== 1'b0)
                $fatal(1, "TX/RX CDC TX FIFO underflow");
            if (rx_dsp_full !== 1'b0)
                $fatal(1, "TX/RX CDC RX FIFO rejected write");
            if ($isunknown(tx_dsp_line))
                $fatal(1, "TX/RX CDC unknown DSP data");
        end
    end

    tx_rx_cdc_test u_tb (vif);

endmodule

program automatic tx_rx_cdc_test (tx_rx_cdc_if vif);

    import tx_rx_cdc_tb_pkg::*;

    tx_rx_cdc_env env;

    initial begin
        string test_mode_arg;
        test_mode_e mode = CLEAN_TEST;

        if ($value$plusargs("TEST_MODE=%s", test_mode_arg)) begin
            case (test_mode_arg)
                "CLEAN", "clean": mode = CLEAN_TEST;
                "BURST", "burst": mode = BURST_TEST;
                default: $fatal(1, "Unknown TEST_MODE=%s. Use CLEAN or BURST", test_mode_arg);
            endcase
        end

        $display("");
        $display("=== TX/RX CDC simulation started ===");

        env = new(vif, mode);
        env.run();

        $display("=== TX/RX CDC simulation finished ===");
        $display("");
        $finish;
    end

endprogram

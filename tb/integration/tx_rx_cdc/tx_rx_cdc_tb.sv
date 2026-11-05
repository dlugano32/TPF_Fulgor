`timescale 1ps/1ps

module tx_rx_cdc_tb;

    // Integer half-periods preserve 889*f_FEC = 1024*f_DSP exactly at 1 ps.
    localparam time FEC_PERIOD = 2 * 889ps;
    localparam time DSP_PERIOD = 2 * 1024ps;
    localparam int unsigned START_LEVEL = 2;

    logic clk_fec = 1'b0;
    logic clk_dsp = 1'b0;
    always #(FEC_PERIOD / 2) clk_fec = ~clk_fec;
    always #(DSP_PERIOD / 2) clk_dsp = ~clk_dsp;

    tx_rx_cdc_if vif (clk_fec, clk_dsp);

    wire [1023:0] tx_line;
    wire tx_empty, tx_full, rx_full;
    wire [3:0] tx_rd_level;
    logic link_started;
    wire transfer;

    tx_top u_tx_top (
        .i_clk_fec      (clk_fec),
        .i_clk_dsp      (clk_dsp),
        .i_arst_n       (vif.i_arst_n),
        .i_en           (vif.i_en),
        .i_seed         (vif.i_seed),
        .i_dsp_rd_en    (transfer),
        .o_line         (tx_line),
        .o_dsp_empty    (tx_empty),
        .o_dsp_rd_level (tx_rd_level),
        .o_fifo_full    (tx_full)
    );

    always_ff @(posedge clk_dsp) begin
        if (!vif.i_arst_n)
            link_started <= 1'b0;
        else if (vif.i_en && tx_rd_level >= START_LEVEL)
            link_started <= 1'b1;
    end

    assign transfer = vif.i_arst_n && vif.i_en && (link_started || tx_rd_level >= START_LEVEL);

    rx_top u_rx_top (
        .i_clk_fec     (clk_fec),
        .i_clk_dsp     (clk_dsp),
        .i_arst_n      (vif.i_arst_n),
        .i_en          (vif.i_en),
        .i_dsp_line    (tx_line),
        .i_dsp_wr_en   (transfer),
        .o_dsp_full    (rx_full),
        .o_payload     (),
        .o_locked      (vif.o_locked),
        .o_error_count (vif.o_error_count),
        .o_valid       (vif.o_valid)
    );

    always @(posedge clk_dsp) begin
        if (transfer) begin
            if (tx_empty !== 1'b0)
                $fatal(1, "TX/RX CDC TX FIFO underflow");
            if (rx_full !== 1'b0)
                $fatal(1, "TX/RX CDC RX FIFO rejected write");
            if ($isunknown(tx_line))
                $fatal(1, "TX/RX CDC unknown DSP data");
        end
    end

    tx_rx_cdc_test u_tb (vif);

endmodule

program automatic tx_rx_cdc_test (tx_rx_cdc_if vif);

    import tx_rx_cdc_tb_pkg::*;

    tx_rx_cdc_env env;

    initial begin

        $display("");
        $display("=== TX/RX CDC simulation started ===");

        env = new(vif);
        env.run();

        $display("=== TX/RX CDC simulation finished ===");
        $display("");
        $finish;
    end

endprogram

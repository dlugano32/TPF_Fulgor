class tx_rx_cdc_drv;

    virtual tx_rx_cdc_if.DRV vif;
    mailbox #(tx_rx_cdc_test_cfg) gen2drv;
    mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg;
    mailbox #(bit)                scb2drv_done;

    bit done = 1'b0;

    function new(
        virtual tx_rx_cdc_if.DRV vif,
        mailbox #(tx_rx_cdc_test_cfg) gen2drv,
        mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg,
        mailbox #(bit) scb2drv_done
    );
        if (vif == null)
            $fatal(1, "tx_rx_cdc_drv: vif is null");

        this.vif          = vif;
        this.gen2drv      = gen2drv;
        this.drv2scb_cfg  = drv2scb_cfg;
        this.scb2drv_done = scb2drv_done;
    endfunction

    task do_reset(seed_t seed);
        @(vif.cb_drv);
        vif.i_arst_n      <= 1'b0;
        vif.cb_drv.i_en   <= 1'b0;
        vif.cb_drv.i_seed <= seed;

        @(vif.cb_dsp);
        vif.cb_dsp.error_mask <= '0;
        vif.cb_dsp.injection_done <= 1'b0;

        repeat (8) @(vif.cb_drv);
        vif.i_arst_n <= 1'b1;
        repeat (3) @(vif.cb_drv);
    endtask

    function automatic logic [DSP_W-1:0] get_burst_mask(tx_rx_cdc_test_cfg cfg, int unsigned word_index);
        logic [DSP_W-1:0] mask = '0;
        for (int unsigned bit_index = 0; bit_index < DSP_W; bit_index++) begin
            int unsigned stream_position = word_index * DSP_W + bit_index;

            if (stream_position >= cfg.burst_offset && stream_position < cfg.burst_offset + cfg.burst_length)
                mask[bit_index] = 1'b1;
        end
        return mask;
    endfunction

    task inject_burst(tx_rx_cdc_test_cfg cfg);
        bit locked_seen = 1'b0;
        int unsigned word_count;

        for (int unsigned cycle = 0; cycle < LOCK_TIMEOUT; cycle++) begin
            @(vif.cb_dsp);
            if (vif.cb_dsp.o_locked === 1'b1) begin
                locked_seen = 1'b1;
                break;
            end
        end

        if (!locked_seen)
            $fatal(1, "TX/RX CDC injector lock timeout test=%0d", cfg.test_index);

        repeat (cfg.burst_delay) @(vif.cb_dsp);

        word_count = (cfg.burst_offset + cfg.burst_length + DSP_W - 1) / DSP_W;

        for (int unsigned word_index = 0; word_index < word_count; word_index++) begin
            vif.cb_dsp.error_mask <= get_burst_mask(cfg, word_index);
            @(vif.cb_dsp);
            if (vif.cb_dsp.dsp_transfer !== 1'b1)
                $fatal(1, "TX/RX CDC burst without DSP transfer test=%0d", cfg.test_index);
        end
        vif.cb_dsp.error_mask <= '0;
        vif.cb_dsp.injection_done <= 1'b1;
        @(vif.cb_dsp);
    endtask

    task drive_test(tx_rx_cdc_test_cfg cfg);
        bit completed;

        do_reset(cfg.seed);
        drv2scb_cfg.put(cfg);
        vif.cb_drv.i_en <= 1'b1;

        // Keep the stream continuous until all requested checker results arrive.
        fork
            begin
                if (cfg.mode == BURST_TEST)
                    inject_burst(cfg);
            end
            scb2drv_done.get(completed);
        join

        // Reset immediately instead of starving RX while attempting to drain TX.
        vif.i_arst_n    <= 1'b0;
        vif.cb_drv.i_en <= 1'b0;
        // Let the clocking outputs settle before this transaction returns.
        @(vif.cb_drv);
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            tx_rx_cdc_test_cfg cfg;

            gen2drv.get(cfg);
            drive_test(cfg);
        end

        done = 1'b1;
    endtask

endclass

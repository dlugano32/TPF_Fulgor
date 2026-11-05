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

        repeat (8) @(vif.cb_drv);
        vif.i_arst_n <= 1'b1;
        repeat (3) @(vif.cb_drv);
    endtask

    task drive_test(tx_rx_cdc_test_cfg cfg);
        bit completed;

        do_reset(cfg.seed);
        drv2scb_cfg.put(cfg);
        vif.cb_drv.i_en <= 1'b1;

        // Keep the stream continuous until all requested checker results arrive.
        scb2drv_done.get(completed);
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

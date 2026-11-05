class tx_rx_cdc_env;

    virtual tx_rx_cdc_if vif;

    mailbox #(tx_rx_cdc_test_cfg) gen2drv;
    mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_cdc_txn)      mon2scb;
    mailbox #(bit)               scb2drv_done;

    tx_rx_cdc_gen gen;
    tx_rx_cdc_drv drv;
    tx_rx_cdc_mon mon;
    tx_rx_cdc_scb scb;

    function new(virtual tx_rx_cdc_if vif);
        this.vif = vif;

        gen2drv      = new();
        drv2scb_cfg  = new();
        mon2scb      = new();
        scb2drv_done = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv, drv2scb_cfg, scb2drv_done);
        mon = new(vif, mon2scb);
        scb = new(drv2scb_cfg, mon2scb, scb2drv_done);
    endfunction

    task run();
        $display("TX/RX CDC regression: mode=CLEAN tests=%0d cycles=[%0d:%0d] lock_timeout=%0d random_seed=%0d",
            N_TESTS, MIN_CYCLES, MAX_CYCLES, LOCK_TIMEOUT, RANDOM_SEED);

        fork
            gen.run(N_TESTS);
            drv.run(N_TESTS);
            mon.run();
            scb.run(N_TESTS);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0 || scb.accumulated_errors != 0)
            $fatal(1, "TX/RX CDC regression failed: mismatches=%0d accumulated_errors=%0d",
                scb.error_count, scb.accumulated_errors);

        $display("TX/RX CDC regression PASS: mode=CLEAN tests=%0d checked_cycles=%0d accumulated_errors=%0d",
            scb.checked_tests, scb.checked_cycles, scb.accumulated_errors);
    endtask

endclass

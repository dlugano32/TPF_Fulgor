class tx_rx_top_env;

    import tx_rx_top_tb_pkg::*;

    virtual tx_rx_top_if vif;
    test_mode_e mode;

    mailbox #(tx_rx_top_test_cfg) gen2drv;
    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_top_txn)      mon2scb;

    tx_rx_top_gen gen;
    tx_rx_top_drv drv;
    tx_rx_top_mon mon;
    tx_rx_top_scb scb;

    function new(virtual tx_rx_top_if vif, test_mode_e mode);
        this.vif = vif;
        this.mode = mode;

        gen2drv     = new();
        drv2scb_cfg = new();
        mon2scb     = new();

        gen = new(gen2drv, mode);
        drv = new(vif, gen2drv, drv2scb_cfg);
        mon = new(vif, mon2scb);
        scb = new(drv2scb_cfg, mon2scb);
    endfunction

    task run();
        int unsigned test_count;

        test_count = (mode == CLEAN_TEST) ? N_TESTS : BURST_TEST_COUNT;

        if (mode == CLEAN_TEST) begin
            $display("TX/RX top regression: mode=CLEAN tests=%0d cycles=[%0d:%0d] lock_timeout=%0d random_seed=%0d",
                test_count, MIN_CYCLES, MAX_CYCLES, LOCK_TIMEOUT, RANDOM_SEED
            );
        end else begin
            $display("TX/RX top regression: mode=BURST tests=%0d post_burst_cycles=%0d lock_timeout=%0d random_seed=%0d",
                test_count, POST_BURST_CYCLES, LOCK_TIMEOUT, RANDOM_SEED
            );
        end

        fork
            gen.run(test_count);
            drv.run(test_count);
            mon.run();
            scb.run(test_count);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "TX/RX top regression failed with %0d mismatches", scb.error_count);

        $display("TX/RX top regression PASS: mode=%s tests=%0d checked_cycles=%0d",
            (mode == CLEAN_TEST) ? "CLEAN" : "BURST",
            scb.checked_tests, scb.checked_cycles
        );
    endtask

endclass

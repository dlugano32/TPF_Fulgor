class tx_rx_top_env;

    import tx_rx_top_tb_pkg::*;

    virtual tx_rx_top_if vif;

    mailbox #(tx_rx_top_test_cfg) gen2drv;
    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_top_txn)      mon2scb;

    tx_rx_top_gen gen;
    tx_rx_top_drv drv;
    tx_rx_top_mon mon;
    tx_rx_top_scb scb;

    function new(virtual tx_rx_top_if vif);
        this.vif = vif;

        gen2drv     = new();
        drv2scb_cfg = new();
        mon2scb     = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv, drv2scb_cfg);
        mon = new(vif, mon2scb);
        scb = new(drv2scb_cfg, mon2scb);
    endfunction

    task run();
        $display("TX/RX top regression: tests=%0d cycles=[%0d:%0d] lock_timeout=%0d random_seed=%0d",
            N_TESTS, MIN_CYCLES, MAX_CYCLES, LOCK_TIMEOUT, RANDOM_SEED
        );

        fork
            gen.run(N_TESTS);
            drv.run(N_TESTS);
            mon.run();
            scb.run(N_TESTS);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "TX/RX top regression failed with %0d mismatches", scb.error_count);

        $display("TX/RX top regression PASS: %0d tests, %0d post-lock cycles, BER=0",
            scb.checked_tests, scb.checked_cycles
        );
    endtask

endclass

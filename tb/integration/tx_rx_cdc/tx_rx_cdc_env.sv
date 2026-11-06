class tx_rx_cdc_env;

    virtual tx_rx_cdc_if vif;
    test_mode_e mode;

    mailbox #(tx_rx_cdc_test_cfg) gen2drv;
    mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_cdc_txn)      mon2scb;
    mailbox #(bit)               scb2drv_done;

    tx_rx_cdc_gen gen;
    tx_rx_cdc_drv drv;
    tx_rx_cdc_mon mon;
    tx_rx_cdc_scb scb;

    function new(virtual tx_rx_cdc_if vif, test_mode_e mode = CLEAN_TEST);
        this.vif = vif;
        this.mode = mode;

        gen2drv      = new();
        drv2scb_cfg  = new();
        mon2scb      = new();
        scb2drv_done = new();

        gen = new(gen2drv, mode);
        drv = new(vif, gen2drv, drv2scb_cfg, scb2drv_done);
        mon = new(vif, mon2scb);
        scb = new(drv2scb_cfg, mon2scb, scb2drv_done);
    endfunction

    task run();
        int unsigned test_count = (mode == CLEAN_TEST) ? N_TESTS : BURST_TEST_COUNT;
        string mode_name = (mode == CLEAN_TEST) ? "CLEAN" : "BURST";

        if (test_count == 0 || (mode == BURST_TEST && (test_count < 5 || test_count % 5 != 0)))
            $fatal(1, "Package test count must be positive; BURST_TEST_COUNT requires a multiple of five");
        $display("TX/RX CDC regression: mode=%s tests=%0d clean_cycles=[%0d:%0d] post_burst_cycles=%0d lock_timeout=%0d random_seed=%0d",
            mode_name, test_count, MIN_CYCLES, MAX_CYCLES, POST_BURST_CYCLES, LOCK_TIMEOUT, RANDOM_SEED);

        fork
            gen.run(test_count);
            drv.run(test_count);
            mon.run();
            scb.run(test_count);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0 || (mode == CLEAN_TEST && scb.accumulated_errors != 0))
            $fatal(1, "TX/RX CDC regression failed: mismatches=%0d accumulated_errors=%0d",
                scb.error_count, scb.accumulated_errors);

        if (mode == BURST_TEST) begin
            for (int unsigned index = 0; index < 5; index++) begin
                int unsigned burst_length;
                case (index)
                    0: burst_length = 98;
                    1: burst_length = 99;
                    2: burst_length = 112;
                    3: burst_length = 113;
                    4: burst_length = 114;
                endcase
                $display("[SUMMARY] burst_length=%0d cases=%0d cases_with_post_fec_errors=%0d",
                    burst_length, scb.burst_cases[index], scb.burst_cases_with_errors[index]);
            end
        end
        $display("TX/RX CDC regression PASS: mode=%s tests=%0d checked_cycles=%0d accumulated_errors=%0d",
            mode_name, scb.checked_tests, scb.checked_cycles, scb.accumulated_errors);
    endtask

endclass

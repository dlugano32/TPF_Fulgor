class tx_rx_cdc_scb;

    mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_cdc_txn)      mon2scb;
    mailbox #(bit)               scb2drv_done;

    int unsigned     checked_tests = 0;
    int unsigned     checked_cycles = 0;
    int unsigned     error_count = 0;
    longint unsigned accumulated_errors = 0;
    bit              done = 1'b0;

    function new(
        mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg,
        mailbox #(tx_rx_cdc_txn) mon2scb,
        mailbox #(bit) scb2drv_done
    );
        this.drv2scb_cfg = drv2scb_cfg;
        this.mon2scb     = mon2scb;
        this.scb2drv_done = scb2drv_done;
    endfunction

    task check_test(tx_rx_cdc_test_cfg cfg);
        bit locked_seen = 1'b0;
        bit results_started = 1'b0;
        int unsigned output_cycles = 0;
        longint unsigned post_fec_errors = 0;
        bit unknown_count = 1'b0;

        for (int unsigned cycle = 0; cycle < LOCK_TIMEOUT; cycle++) begin
            tx_rx_cdc_txn actual;

            mon2scb.get(actual);

            if (actual.locked === 1'b1) begin
                locked_seen = 1'b1;
                break;
            end
        end

        if (!locked_seen)
            $fatal(1, "TX/RX CDC lock timeout test=%0d seed=0x%08h timeout=%0d",
                cfg.test_index, cfg.seed, LOCK_TIMEOUT);

        // Count valid error reports, after the first report no gaps are allowed.
        for (int unsigned cycle = 0; cycle < cfg.cycles + CHECKER_TIMEOUT; cycle++) begin
            tx_rx_cdc_txn actual;

            mon2scb.get(actual);
            if (actual.locked !== 1'b1)
                $fatal(1, "TX/RX CDC lost lock test=%0d result=%0d", cfg.test_index, output_cycles);
            if ($isunknown(actual.valid))
                $fatal(1, "TX/RX CDC unknown o_valid test=%0d", cfg.test_index);

            if (actual.valid) begin
                results_started = 1'b1;
                if ($isunknown(actual.error_count))
                    unknown_count = 1'b1;
                else
                    post_fec_errors += actual.error_count;

                output_cycles++;
                checked_cycles++;
                if (output_cycles == cfg.cycles)
                    break;
            end else if (results_started) begin
                $fatal(1, "TX/RX CDC missing result test=%0d result=%0d", cfg.test_index, output_cycles);
            end else if (cycle + 1 >= CHECKER_TIMEOUT) begin
                $fatal(1, "TX/RX CDC first result timeout test=%0d", cfg.test_index);
            end
        end

        if (output_cycles != cfg.cycles)
            $fatal(1, "TX/RX CDC result count mismatch test=%0d expected=%0d received=%0d",
                cfg.test_index, cfg.cycles, output_cycles);

        accumulated_errors += post_fec_errors;
        if (unknown_count || post_fec_errors != 0) begin
            $error("TX/RX CDC mismatch test=%0d seed=0x%08h post_fec_errors=%0d unknown_count=%0b",
                cfg.test_index, cfg.seed, post_fec_errors, unknown_count);
            error_count++;
        end

        $display("[SCB] mode=CLEAN test=%0d seed=0x%08h checked_cycles=%0d post_fec_errors=%0d",
            cfg.test_index, cfg.seed, output_cycles, post_fec_errors);

        checked_tests++;
        scb2drv_done.put(1'b1);
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            tx_rx_cdc_test_cfg cfg;

            drv2scb_cfg.get(cfg);
            check_test(cfg);
        end

        done = 1'b1;
    endtask

endclass

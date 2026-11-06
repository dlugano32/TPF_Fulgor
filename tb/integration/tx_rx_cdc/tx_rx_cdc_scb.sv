class tx_rx_cdc_scb;

    mailbox #(tx_rx_cdc_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_cdc_txn)      mon2scb;
    mailbox #(bit)               scb2drv_done;

    int unsigned     checked_tests = 0;
    int unsigned     checked_cycles = 0;
    int unsigned     error_count = 0;
    longint unsigned accumulated_errors = 0;
    bit              done = 1'b0;
    int unsigned     burst_cases [5];
    int unsigned     burst_cases_with_errors [5];

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
        int unsigned remaining_cycles = cfg.cycles;
        int unsigned wait_cycles = 0;

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

        // Accumulate every valid report. BURST ends after cfg.cycles valid
        // reports following injection_done; CLEAN counts from acquisition.
        while (remaining_cycles != 0) begin
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
                if (cfg.mode == CLEAN_TEST || actual.injection_done === 1'b1)
                    remaining_cycles--;
            end else if (results_started) begin
                $fatal(1, "TX/RX CDC missing result test=%0d result=%0d", cfg.test_index, output_cycles);
            end else begin
                wait_cycles++;
                if (wait_cycles >= CHECKER_TIMEOUT)
                    $fatal(1, "TX/RX CDC first result timeout test=%0d", cfg.test_index);
            end
        end

        accumulated_errors += post_fec_errors;
        if (cfg.mode == BURST_TEST) begin
            int unsigned length_index = cfg.test_index % 5;
            burst_cases[length_index]++;
            if (post_fec_errors != 0)
                burst_cases_with_errors[length_index]++;
        end

        if (unknown_count ||
            ((cfg.mode == CLEAN_TEST || cfg.burst_length == 98) && post_fec_errors != 0) ||
            (cfg.mode == BURST_TEST && cfg.burst_length == 114 && post_fec_errors == 0)) begin
            $error("TX/RX CDC mismatch test=%0d seed=0x%08h post_fec_errors=%0d unknown_count=%0b",
                cfg.test_index, cfg.seed, post_fec_errors, unknown_count);
            error_count++;
        end

        $display("[SCB] mode=%s test=%0d seed=0x%08h checked_cycles=%0d burst_length=%0d dsp_offset=%0d post_fec_errors=%0d",
            (cfg.mode == CLEAN_TEST) ? "CLEAN" : "BURST", cfg.test_index, cfg.seed,
            output_cycles, cfg.burst_length, cfg.burst_offset, post_fec_errors);

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

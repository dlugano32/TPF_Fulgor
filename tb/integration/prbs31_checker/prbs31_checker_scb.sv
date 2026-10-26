class prbs31_checker_scb;

    mailbox #(prbs31_checker_test_cfg) drv2scb_cfg;
    mailbox #(prbs31_checker_txn)      drv2scb_frame;
    mailbox #(prbs31_checker_txn)      mon2scb;
    mailbox #(bit)                    scb2drv_done;

    int unsigned checked_tests  = 0;
    int unsigned checked_frames = 0;
    int unsigned checked_counts = 0;
    int unsigned error_count    = 0;
    bit          done           = 1'b0;

    function new(
        mailbox #(prbs31_checker_test_cfg) drv2scb_cfg,
        mailbox #(prbs31_checker_txn) drv2scb_frame,
        mailbox #(prbs31_checker_txn) mon2scb,
        mailbox #(bit) scb2drv_done
    );
        this.drv2scb_cfg   = drv2scb_cfg;
        this.drv2scb_frame = drv2scb_frame;
        this.mon2scb       = mon2scb;
        this.scb2drv_done  = scb2drv_done;
    endfunction

    task check_frame(
        prbs31_checker_test_cfg cfg,
        prbs31_checker_txn expected,
        prbs31_checker_txn actual,
        output bit model_locked
    );
        int unsigned model_error_count;
        bit expected_locked;
        int unsigned expected_error_count;
        prbs_t expected_received_data;

        // Advance the C model only when an input is accepted, regardless of o_valid.
        prbs31_checker_dpi(actual.received_data, model_locked, model_error_count);

        expected_received_data = actual.generated_data ^ expected.error_mask;
        expected_locked = !((cfg.scenario == SEED_FAILURE) && (expected.frame_index == 0));
        expected_error_count = ((cfg.scenario == FRAME_ERRORS) && (expected.frame_index > 0)) ? expected.n_errors : 0;

        if ((actual.received_data !== expected_received_data) ||
            (actual.locked !== model_locked) ||
            (actual.locked !== expected_locked) ||
            (model_error_count != expected_error_count)) begin
            $error("PRBS31 checker input mismatch test=%0d scenario=%s frame=%0d mask_errors=%0d",
                cfg.test_index, cfg.scenario.name(), expected.frame_index, expected.n_errors);
            $display("[expected] locked=%0b count=%0d [model] locked=%0b count=%0d [RTL] locked=%0b",
                expected_locked, expected_error_count, model_locked, model_error_count, actual.locked);
            error_count++;
        end

        expected.error_count = model_error_count[CNT_W - 1 : 0];
        checked_frames++;
    endtask

    task check_test(prbs31_checker_test_cfg cfg);
        prbs31_checker_txn pending[$];
        int unsigned input_frames = 0;
        bit model_locked = 1'b0;

        prbs31_checker_reset_dpi();

        // Input acceptance and output validity are independent events.
        // Only blocks accepted while already locked produce a count.
        while ((input_frames < cfg.cycles) || (pending.size() != 0)) begin
            prbs31_checker_txn actual;
            mon2scb.get(actual);

            if (actual.input_valid === 1'b1) begin
                prbs31_checker_txn expected;
                bit was_locked = model_locked;

                if (input_frames >= cfg.cycles)
                    $fatal(1, "Unexpected extra input in test %0d", cfg.test_index);

                drv2scb_frame.get(expected);
                check_frame(cfg, expected, actual, model_locked);
                if (was_locked)
                    pending.push_back(expected);
                input_frames++;
            end

            if ($isunknown(actual.output_valid)) begin
                $error("Unknown o_valid in test %0d", cfg.test_index);
                error_count++;
            end else if (actual.output_valid) begin
                prbs31_checker_txn expected;

                if (pending.size() == 0)
                    $fatal(1, "Unexpected o_valid without a pending count in test %0d", cfg.test_index);

                expected = pending.pop_front();
                if (actual.error_count !== expected.error_count) begin
                    $error("PRBS31 checker count mismatch test=%0d scenario=%s frame=%0d expected=%0d actual=%0d",
                        cfg.test_index, cfg.scenario.name(), expected.frame_index,
                        expected.error_count, actual.error_count);
                    error_count++;
                end
                checked_counts++;
            end
        end

        checked_tests++;
        scb2drv_done.put(1'b1);
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            prbs31_checker_test_cfg cfg;
            drv2scb_cfg.get(cfg);
            check_test(cfg);
        end
        done = 1'b1;
    endtask

endclass

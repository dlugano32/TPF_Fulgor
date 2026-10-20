class prbs31_checker_scb;

    mailbox #(prbs31_checker_test_cfg) drv2scb_cfg;
    mailbox #(prbs31_checker_txn)      drv2scb_frame;
    mailbox #(prbs31_checker_txn)      mon2scb;

    int unsigned checked_tests  = 0;
    int unsigned checked_frames = 0;
    int unsigned error_count    = 0;
    bit          done           = 1'b0;

    function new(
        mailbox #(prbs31_checker_test_cfg) drv2scb_cfg,
        mailbox #(prbs31_checker_txn) drv2scb_frame,
        mailbox #(prbs31_checker_txn) mon2scb
    );
        this.drv2scb_cfg   = drv2scb_cfg;
        this.drv2scb_frame = drv2scb_frame;
        this.mon2scb       = mon2scb;
    endfunction

    task check_frame(prbs31_checker_test_cfg cfg, prbs31_checker_txn expected, prbs31_checker_txn actual);
        bit model_locked;
        int unsigned model_error_count;
        bit expected_locked;
        int unsigned expected_error_count;
        prbs_t expected_received_data;

        // The model sees the received frame, including the injected errors, in the same order as the RTL.
        prbs31_checker_dpi(actual.received_data, model_locked, model_error_count);

        // Independent scenario expectations:
        // CLEAN        : locked/count = 1/0 from frame 0 onward.
        // SEED_FAILURE : frame 0 = 0/0, frame 1 onward = 1/0.
        // FRAME_ERRORS : frame 0 = 1/0, later count equals mask weight.
        expected_received_data = actual.generated_data ^ expected.error_mask;
        expected_locked = !((cfg.scenario == SEED_FAILURE) && (expected.frame_index == 0));
        expected_error_count = ((cfg.scenario == FRAME_ERRORS) && (expected.frame_index > 0)) ? expected.n_errors : 0; 

        if ((actual.received_data !== expected_received_data) ||         // Check if received data is the same as the generated with errors
            (actual.locked !== model_locked) ||                          // Check if both model and RTL are locked
            (actual.error_count !== model_error_count[CNT_W - 1 : 0]) || // Check if both model and RTL errors are the same
            (actual.locked !== expected_locked) ||                       // Check if the RTL was expected to be locked
            (actual.error_count !== expected_error_count[CNT_W - 1 : 0])) begin // Check if the expected errors are according to the scene test

            $error("PRBS31 checker mismatch test=%0d scenario=%s frame=%0d mask_errors=%0d",
                cfg.test_index, cfg.scenario.name(), expected.frame_index, expected.n_errors
            );

            $display("[expected] locked=%0b error_count=%0d model_locked=%0b model_error_count=%0d",
                expected_locked, expected_error_count, model_locked, model_error_count
            );

            $display("[actual]   locked=%0b error_count=%0d",
                actual.locked, actual.error_count
            );
            error_count++;
        end

        checked_frames++;
    endtask

    task check_test(prbs31_checker_test_cfg cfg);
        prbs31_checker_reset_dpi();

        for (int unsigned frame_index = 0; frame_index < cfg.cycles; frame_index++) begin
            prbs31_checker_txn expected;
            prbs31_checker_txn actual;

            drv2scb_frame.get(expected);
            mon2scb.get(actual);
            check_frame(cfg, expected, actual);
        end

        checked_tests++;
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

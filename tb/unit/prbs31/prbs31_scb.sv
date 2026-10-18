class prbs31_scb;

    mailbox #(prbs31_txn) drv2scb;
    mailbox #(prbs31_txn) mon2scb;

    int unsigned checked_tests  = 0;
    int unsigned checked_cycles = 0;
    int unsigned error_count    = 0;
    bit          done           = 1'b0;

    function new(mailbox #(prbs31_txn) drv2scb, mailbox #(prbs31_txn) mon2scb);
        this.drv2scb = drv2scb;
        this.mon2scb = mon2scb;
    endfunction

    task check_test(prbs31_txn test_cfg);
        prbs31_reset_dpi(test_cfg.seed);

        for (int unsigned cycle = 0; cycle < test_cfg.cycles; cycle++) begin
            prbs31_txn actual;
            prbs_t expected;

            mon2scb.get(actual);
            prbs31_gen_dpi(expected);

            if (actual.prbs !== expected) begin
                $error("PRBS31 mismatch test=%0d cycle=%0d seed=0x%08h", test_cfg.test_index, cycle, test_cfg.seed);
                error_count++;
            end

            checked_cycles++;
        end

        checked_tests++;
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            prbs31_txn test_cfg;

            drv2scb.get(test_cfg);
            check_test(test_cfg);
        end

        done = 1'b1;
    endtask

endclass

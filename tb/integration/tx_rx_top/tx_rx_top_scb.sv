class tx_rx_top_scb;

    import tx_rx_top_tb_pkg::*;

    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_top_txn)      mon2scb;

    int unsigned checked_tests  = 0;
    int unsigned checked_cycles = 0;
    int unsigned error_count    = 0;
    bit          done           = 1'b0;

    function new(
        mailbox #(tx_rx_top_test_cfg) drv2scb_cfg,
        mailbox #(tx_rx_top_txn) mon2scb
    );
        this.drv2scb_cfg = drv2scb_cfg;
        this.mon2scb     = mon2scb;
    endfunction

    task check_test(tx_rx_top_test_cfg cfg);
        bit locked_seen = 1'b0;

        for (int unsigned cycle = 0; cycle < LOCK_TIMEOUT; cycle++) begin
            tx_rx_top_txn actual;

            mon2scb.get(actual);
            if (actual.locked === 1'b1) begin
                locked_seen = 1'b1;
                break;
            end
        end

        if (!locked_seen) begin
            $error("TX/RX top lock timeout test=%0d seed=0x%08h timeout=%0d",
                cfg.test_index, cfg.seed, LOCK_TIMEOUT
            );
            error_count++;
        end else begin
            for (int unsigned cycle = 0; cycle < cfg.cycles; cycle++) begin
                tx_rx_top_txn actual;

                mon2scb.get(actual);

                if ((actual.locked !== 1'b1) || (actual.error_count !== '0)) begin
                    $error("TX/RX top BER mismatch test=%0d seed=0x%08h cycle=%0d locked=%0b error_count=%0d",
                        cfg.test_index, cfg.seed, cycle, actual.locked, actual.error_count
                    );
                    error_count++;
                end

                checked_cycles++;
            end
        end

        checked_tests++;
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            tx_rx_top_test_cfg cfg;

            drv2scb_cfg.get(cfg);
            check_test(cfg);
        end

        done = 1'b1;
    endtask

endclass

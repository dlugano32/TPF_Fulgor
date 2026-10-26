class tx_rx_top_scb;

    import tx_rx_top_tb_pkg::*;

    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;
    mailbox #(tx_rx_top_txn)      mon2scb;
    mailbox #(bit)               scb2drv_done;

    int unsigned checked_tests  = 0;
    int unsigned checked_cycles = 0;
    int unsigned error_count    = 0;
    bit          done           = 1'b0;

    function new(
        mailbox #(tx_rx_top_test_cfg) drv2scb_cfg,
        mailbox #(tx_rx_top_txn) mon2scb,
        mailbox #(bit) scb2drv_done
    );
        this.drv2scb_cfg = drv2scb_cfg;
        this.mon2scb     = mon2scb;
        this.scb2drv_done = scb2drv_done;
    endfunction

    task collect_cycles(
        tx_rx_top_test_cfg cfg,
        output int unsigned injected_bits,
        output int unsigned post_fec_errors,
        output bit unknown_count
    );
        int unsigned input_cycles = 0;
        int unsigned output_cycles = 0;

        injected_bits = 0;
        post_fec_errors = 0;
        unknown_count = 1'b0;

        // After acquisition, every enabled input produces one valid count.
        // Keep sampling after i_en falls until all pending results arrive.
        while ((input_cycles < cfg.cycles) || (output_cycles < cfg.cycles)) begin
            tx_rx_top_txn actual;
            mon2scb.get(actual);

            if (actual.locked !== 1'b1) begin
                $error("TX/RX lost lock test=%0d input_cycle=%0d output_cycle=%0d",
                    cfg.test_index, input_cycles, output_cycles);
                error_count++;
            end

            if (actual.input_valid === 1'b1) begin
                if (input_cycles >= cfg.cycles)
                    $fatal(1, "TX/RX unexpected extra input test=%0d", cfg.test_index);

                if ($isunknown(actual.error_mask)) begin
                    $error("TX/RX unknown injection mask test=%0d cycle=%0d",
                        cfg.test_index, input_cycles);
                    error_count++;
                end else begin
                    injected_bits += $countones(actual.error_mask);
                end

                input_cycles++;
                checked_cycles++;
            end

            if ($isunknown(actual.output_valid)) begin
                $error("TX/RX unknown o_valid test=%0d", cfg.test_index);
                error_count++;
            end else if (actual.output_valid) begin
                if (output_cycles >= input_cycles)
                    $fatal(1, "TX/RX o_valid without a pending input test=%0d", cfg.test_index);

                if ($isunknown(actual.error_count))
                    unknown_count = 1'b1;
                else
                    post_fec_errors += actual.error_count;

                output_cycles++;
            end
        end
    endtask

    task check_clean_cycles(tx_rx_top_test_cfg cfg);
        int unsigned injected_bits;
        int unsigned post_fec_errors;
        bit unknown_count;

        collect_cycles(cfg, injected_bits, post_fec_errors, unknown_count);
        if ((injected_bits != 0) || unknown_count || (post_fec_errors != 0)) begin
            $error("TX/RX clean mismatch test=%0d seed=0x%08h injected_bits=%0d post_fec_errors=%0d unknown_count=%0b",
                cfg.test_index, cfg.seed, injected_bits, post_fec_errors, unknown_count);
            error_count++;
        end
    endtask

    task check_burst_cycles(tx_rx_top_test_cfg cfg);
        int unsigned injected_bits  = 0;
        int unsigned post_fec_errors = 0;
        bit          unknown_count   = 1'b0;

        collect_cycles(cfg, injected_bits, post_fec_errors, unknown_count);

        if (injected_bits != cfg.burst_length) begin
            $error("TX/RX burst injection mismatch test=%0d expected_bits=%0d injected_bits=%0d",
                cfg.test_index, cfg.burst_length, injected_bits
            );
            error_count++;
        end

        if (unknown_count) begin
            $error("TX/RX burst produced unknown error_count test=%0d", cfg.test_index);
            error_count++;
        end else if (!cfg.expect_post_fec_errors && (post_fec_errors != 0)) begin
            $error("TX/RX correctable burst failed test=%0d length=%0d offset=%0d post_fec_errors=%0d",
                cfg.test_index, cfg.burst_length, cfg.burst_offset, post_fec_errors
            );
            error_count++;
        end else if (cfg.expect_post_fec_errors && (post_fec_errors == 0)) begin
            $error("TX/RX uncorrectable burst was not detected test=%0d length=%0d offset=%0d",
                cfg.test_index, cfg.burst_length, cfg.burst_offset
            );
            error_count++;
        end

        $display("[SCB] burst test=%0d length=%0d offset=%0d injected_bits=%0d post_fec_errors=%0d",
            cfg.test_index, cfg.burst_length, cfg.burst_offset,
            injected_bits, post_fec_errors
        );
    endtask

    task check_test(tx_rx_top_test_cfg cfg);
        bit locked_seen = 1'b0;

        for (int unsigned cycle = 0; cycle < LOCK_TIMEOUT; cycle++) begin
            tx_rx_top_txn actual;

            mon2scb.get(actual);
            if (actual.output_valid !== 1'b0) begin
                $error("TX/RX unexpected o_valid before acquisition test=%0d", cfg.test_index);
                error_count++;
            end
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
            if (cfg.mode == CLEAN_TEST)
                check_clean_cycles(cfg);
            else
                check_burst_cycles(cfg);
        end

        checked_tests++;
        scb2drv_done.put(1'b1);
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

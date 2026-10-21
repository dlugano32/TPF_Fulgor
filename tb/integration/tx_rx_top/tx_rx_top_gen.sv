class tx_rx_top_gen;

    import tx_rx_top_tb_pkg::*;

    mailbox #(tx_rx_top_test_cfg) gen2drv;
    test_mode_e mode;

    function new(mailbox #(tx_rx_top_test_cfg) gen2drv, test_mode_e mode);
        this.gen2drv = gen2drv;
        this.mode    = mode;
    endfunction

    function void configure_burst(tx_rx_top_test_cfg cfg, int unsigned test_index);
        case (test_index)
            0: begin cfg.burst_length =  98; cfg.burst_offset =   0; cfg.expect_post_fec_errors = 1'b0; end
            1: begin cfg.burst_length =  98; cfg.burst_offset = 888; cfg.expect_post_fec_errors = 1'b0; end
            2: begin cfg.burst_length =  99; cfg.burst_offset =   0; cfg.expect_post_fec_errors = 1'b0; end
            3: begin cfg.burst_length =  99; cfg.burst_offset = 888; cfg.expect_post_fec_errors = 1'b1; end
            4: begin cfg.burst_length = 112; cfg.burst_offset =   0; cfg.expect_post_fec_errors = 1'b0; end
            5: begin cfg.burst_length = 112; cfg.burst_offset = 888; cfg.expect_post_fec_errors = 1'b1; end
            6: begin cfg.burst_length = 113; cfg.burst_offset = 777; cfg.expect_post_fec_errors = 1'b0; end
            7: begin cfg.burst_length = 113; cfg.burst_offset =   0; cfg.expect_post_fec_errors = 1'b1; end
            8: begin cfg.burst_length = 114; cfg.burst_offset =   0; cfg.expect_post_fec_errors = 1'b1; end
            9: begin cfg.burst_length = 114; cfg.burst_offset = 888; cfg.expect_post_fec_errors = 1'b1; end
            default: $fatal(1, "Unknown burst test index %0d", test_index);
        endcase

        cfg.cycles = PRE_BURST_CYCLES +
                     ((cfg.burst_offset + cfg.burst_length + LINE_W - 1) / LINE_W) +
                     POST_BURST_CYCLES;
    endfunction

    task run(int unsigned test_count);
        process current_process = process::self();

        current_process.srandom(RANDOM_SEED);

        for (int unsigned test_index = 0; test_index < test_count; test_index++) begin
            tx_rx_top_test_cfg cfg = new();

            if (!cfg.randomize())
                $fatal(1, "Could not randomize TX/RX top test %0d", test_index);

            cfg.mode       = mode;
            cfg.test_index = test_index;

            if (mode == BURST_TEST)
                configure_burst(cfg, test_index);

            cfg.display("GEN");
            gen2drv.put(cfg);
        end
    endtask

endclass

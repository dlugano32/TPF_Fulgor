class tx_rx_cdc_gen;

    mailbox #(tx_rx_cdc_test_cfg) gen2drv;
    test_mode_e mode;

    function new(mailbox #(tx_rx_cdc_test_cfg) gen2drv, test_mode_e mode);
        this.gen2drv = gen2drv;
        this.mode = mode;
    endfunction

    task run(int unsigned test_count);
        process current_process = process::self();

        current_process.srandom(RANDOM_SEED);

        for (int unsigned test_index = 0; test_index < test_count; test_index++) begin
            tx_rx_cdc_test_cfg cfg = new();

            cfg.mode = mode;
            if (mode == BURST_TEST) begin
                case (test_index % 5)
                    0: cfg.burst_length = 98;
                    1: cfg.burst_length = 99;
                    2: cfg.burst_length = 112;
                    3: cfg.burst_length = 113;
                    4: cfg.burst_length = 114;
                endcase
            end

            if (!cfg.randomize())
                $fatal(1, "Could not randomize TX/RX CDC test %0d", test_index);

            cfg.test_index = test_index;
            cfg.display("GEN");
            gen2drv.put(cfg);
        end
    endtask

endclass

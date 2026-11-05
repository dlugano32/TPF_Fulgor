class tx_rx_cdc_gen;

    mailbox #(tx_rx_cdc_test_cfg) gen2drv;

    function new(mailbox #(tx_rx_cdc_test_cfg) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run(int unsigned test_count);
        process current_process = process::self();

        current_process.srandom(RANDOM_SEED);

        for (int unsigned test_index = 0; test_index < test_count; test_index++) begin
            tx_rx_cdc_test_cfg cfg = new();

            if (!cfg.randomize())
                $fatal(1, "Could not randomize TX/RX CDC test %0d", test_index);

            cfg.test_index = test_index;
            cfg.display("GEN");
            gen2drv.put(cfg);
        end
    endtask

endclass

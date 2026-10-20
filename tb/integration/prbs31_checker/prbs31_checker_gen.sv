class prbs31_checker_gen;

    import prbs31_checker_tb_pkg::*;

    mailbox #(prbs31_checker_test_cfg) gen2drv;

    function new(mailbox #(prbs31_checker_test_cfg) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run(int unsigned tests_per_scenario);
        process current_process = process::self();
        int unsigned test_index = 0;

        current_process.srandom(RANDOM_SEED);

        for (int unsigned scenario_index = 0; scenario_index < SCENARIO_COUNT; scenario_index++) begin
            repeat (tests_per_scenario) begin
                prbs31_checker_test_cfg cfg = new();

                cfg.scenario = checker_scenario_e'(scenario_index);

                if (!cfg.randomize())
                    $fatal(1, "Could not randomize PRBS31 checker test %0d", test_index);

                cfg.test_index = test_index++;
                cfg.display("GEN");
                gen2drv.put(cfg);
            end
        end
    endtask

endclass

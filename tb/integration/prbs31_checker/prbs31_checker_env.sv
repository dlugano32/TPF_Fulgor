class prbs31_checker_env;

    import prbs31_checker_tb_pkg::*;

    localparam int unsigned N_TESTS_PER_SCENARIO = 100;                         // gen.run() emits every scenario N_TESTS_PER_SCENARIO times
    localparam int unsigned N_TESTS = SCENARIO_COUNT * N_TESTS_PER_SCENARIO;    // driver and scoreboard consume SCENARIO_COUNT times N_TESTS_PER_SCENARIO.

    virtual prbs31_checker_if vif;

    mailbox #(prbs31_checker_test_cfg) gen2drv;       // One configuration per test.
    mailbox #(prbs31_checker_test_cfg) drv2scb_cfg;   // Tells the scoreboard how many frames to consume.
    mailbox #(prbs31_checker_txn)      drv2scb_frame; // Expected mask and data for each frame.
    mailbox #(prbs31_checker_txn)      mon2scb;       // Aligned RTL input/output sample for each frame.

    prbs31_checker_gen gen;
    prbs31_checker_drv drv;
    prbs31_checker_mon mon;
    prbs31_checker_scb scb;

    function new(virtual prbs31_checker_if vif);
        this.vif = vif;

        gen2drv       = new();
        drv2scb_cfg   = new();
        drv2scb_frame = new();
        mon2scb       = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv, drv2scb_cfg, drv2scb_frame);
        mon = new(vif, mon2scb);
        scb = new(drv2scb_cfg, drv2scb_frame, mon2scb);
    endfunction

    task run();
        $display(
            "PRBS31 checker regression: tests_per_scenario=%0d total_tests=%0d seed=%0d",
            N_TESTS_PER_SCENARIO, N_TESTS, RANDOM_SEED
        );

        fork
            gen.run(N_TESTS_PER_SCENARIO);
            drv.run(N_TESTS);
            mon.run();
            scb.run(N_TESTS);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "PRBS31 checker regression failed with %0d mismatches", scb.error_count);

        $display("PRBS31 checker regression PASS: %0d tests, %0d frames matched", scb.checked_tests, scb.checked_frames);
    endtask

endclass

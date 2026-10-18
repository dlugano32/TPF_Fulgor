class prbs31_env;

    localparam int unsigned N_TESTS = 100;

    virtual prbs31_if vif;

    mailbox #(prbs31_txn) gen2drv;
    mailbox #(prbs31_txn) drv2scb;
    mailbox #(prbs31_txn) mon2scb;

    prbs31_gen gen;
    prbs31_drv drv;
    prbs31_mon mon;
    prbs31_scb scb;

    function new(virtual prbs31_if vif);
        this.vif = vif;

        gen2drv = new();
        drv2scb = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv, drv2scb);
        mon = new(vif, mon2scb);
        scb = new(drv2scb, mon2scb);
    endfunction

    task run();
        fork
            gen.run(N_TESTS);
            drv.run(N_TESTS);
            mon.run();
            scb.run(N_TESTS);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "PRBS31 regression failed with %0d mismatches", scb.error_count);

        $display("PRBS31 regression PASS: %0d tests, %0d cycles matched", scb.checked_tests, scb.checked_cycles);
    endtask

endclass

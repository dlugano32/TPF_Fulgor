class bch_encoder_env;

    virtual bch_encoder_if vif;

    mailbox #(bch_encoder_txn) gen2drv;
    mailbox #(bch_encoder_txn) mon2scb;

    bch_encoder_gen gen;
    bch_encoder_drv drv;
    bch_encoder_mon mon;
    bch_encoder_scb scb;

    int unsigned n_random = 1000;
    int unsigned txn_count = 2 + K + n_random;

    function new(virtual bch_encoder_if vif);
        this.vif = vif;

        gen2drv = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction

    task run();
        fork
            gen.run(n_random);
            drv.run(txn_count);
            mon.run();
            scb.run(txn_count);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "BCH encoder regression failed with %0d mismatches", scb.error_count);

        $display("BCH encoder regression PASS: %0d codewords matched", scb.checked_count);
    endtask

endclass

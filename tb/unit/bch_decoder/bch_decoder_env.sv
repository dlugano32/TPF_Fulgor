class bch_decoder_env;

    virtual bch_decoder_if vif;

    mailbox #(bch_decoder_txn) gen2drv;
    mailbox #(bch_decoder_txn) mon2scb;

    bch_decoder_gen gen;
    bch_decoder_drv drv;
    bch_decoder_mon mon;
    bch_decoder_scb scb;

    // 1 (no error) + 127 (single-error) + 8001(double-error) = 8129 correctable error patterns
    int unsigned txn_count = 1 + N + (N * (N - 1)) / 2;

    function new(virtual bch_decoder_if vif);
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
            gen.run();
            drv.run(txn_count);
            mon.run();
            scb.run(txn_count);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "BCH decoder regression failed with %0d mismatches", scb.error_count);

        $display("BCH decoder regression PASS: %0d received words matched", scb.checked_count);
    endtask

endclass

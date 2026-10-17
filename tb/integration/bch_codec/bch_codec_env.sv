class bch_codec_env;

    import bch_codec_tb_pkg::*;

    virtual bch_codec_if vif;

    mailbox #(bch_codec_txn) gen2drv;
    mailbox #(bch_codec_txn) drv2scb;
    mailbox #(bch_codec_txn) mon2scb;

    bch_codec_gen gen;
    bch_codec_drv drv;
    bch_codec_mon mon;
    bch_codec_scb scb;

    function new(virtual bch_codec_if vif);
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
        $display(
            "BCH codec regression: random=%0d correctable_patterns=%0d total=%0d seed=%0d",
            RANDOM_MESSAGE_COUNT, CORRECTABLE_PATTERN_COUNT, TRANSACTION_COUNT, RANDOM_SEED
        );

        fork
            gen.run();
            drv.run(TRANSACTION_COUNT);
            mon.run();
            scb.run(TRANSACTION_COUNT);
        join_none

        wait (drv.done && scb.done);

        if (scb.error_count != 0)
            $fatal(1, "BCH codec regression failed with %0d mismatches", scb.error_count);

        $display("BCH codec regression PASS: %0d transactions matched", scb.checked_count);
    endtask

endclass

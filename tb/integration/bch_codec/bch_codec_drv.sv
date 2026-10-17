class bch_codec_drv;

    virtual bch_codec_if.DRV vif;
    mailbox #(bch_codec_txn) gen2drv;
    mailbox #(bch_codec_txn) drv2scb;

    bit done = 0;

    function new(virtual bch_codec_if.DRV vif, mailbox #(bch_codec_txn) gen2drv, mailbox #(bch_codec_txn) drv2scb);
        if (vif == null)
            $fatal(1, "bch_codec_drv: vif is null");

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2scb = drv2scb;
    endfunction

    task do_reset(int unsigned cycles = 3);
        vif.cb_drv.i_rst_n      <= 1'b0;
        vif.cb_drv.i_msg        <= '0;
        vif.cb_drv.i_error_mask <= '0;
        vif.cb_drv.i_valid      <= 1'b0;

        repeat (cycles) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    task run(int unsigned txn_count);
        bch_codec_txn txn;

        do_reset();

        repeat (txn_count) begin
            bch_codec_txn expected = new();

            gen2drv.get(txn);
            @(vif.cb_drv);
            vif.cb_drv.i_msg        <= txn.msg;
            vif.cb_drv.i_error_mask <= txn.error_mask;
            vif.cb_drv.i_valid      <= 1'b1;

            expected.msg        = txn.msg;
            expected.error_mask = txn.error_mask;
            drv2scb.put(expected);
        end

        @(vif.cb_drv);
        vif.cb_drv.i_msg        <= '0;
        vif.cb_drv.i_error_mask <= '0;
        vif.cb_drv.i_valid      <= 1'b0;
        done = 1'b1;
    endtask

endclass

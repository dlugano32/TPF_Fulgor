class bch_decoder_drv;

    virtual bch_decoder_if.DRV vif;
    mailbox #(bch_decoder_txn) gen2drv;

    bit done = 0;

    function new(virtual bch_decoder_if.DRV vif, mailbox #(bch_decoder_txn) gen2drv);
        if (vif == null)
            $fatal(1, "bch_decoder_drv: vif is null");

        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task do_reset(int unsigned cycles = 3);
        vif.cb_drv.i_rst_n <= 1'b0;
        vif.cb_drv.i_rx    <= '0;
        vif.cb_drv.i_valid <= 1'b0;

        repeat (cycles) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    task run(int unsigned txn_count);
        bch_decoder_txn txn;

        do_reset();

        repeat (txn_count) begin
            gen2drv.get(txn);
            @(vif.cb_drv);
            vif.cb_drv.i_rx    <= txn.rx;
            vif.cb_drv.i_valid <= 1'b1;
        end

        @(vif.cb_drv);
        vif.cb_drv.i_rx    <= '0;
        vif.cb_drv.i_valid <= 1'b0;
        done = 1'b1;
    endtask

endclass

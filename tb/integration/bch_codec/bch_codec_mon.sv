class bch_codec_mon;

    virtual bch_codec_if.MON vif;
    mailbox #(bch_codec_txn) mon2scb;

    function new(virtual bch_codec_if.MON vif, mailbox #(bch_codec_txn) mon2scb);
        if (vif == null)
            $fatal(1, "bch_codec_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.o_valid === 1'b1)) begin
                bch_codec_txn txn = new();

                txn.encoded_cw    = vif.cb_mon.encoded_cw_aligned;
                txn.rx            = vif.cb_mon.rx_aligned;
                txn.err           = vif.cb_mon.o_err;
                txn.decoded_cw    = vif.cb_mon.o_cw;
                txn.decoded_msg   = vif.cb_mon.o_msg;
                txn.corrected     = vif.cb_mon.o_corrected;
                txn.uncorrectable = vif.cb_mon.o_uncorrectable;
                mon2scb.put(txn);
            end
        end
    endtask

endclass

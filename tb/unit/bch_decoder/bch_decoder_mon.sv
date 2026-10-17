class bch_decoder_mon;

    virtual bch_decoder_if.MON vif;
    mailbox #(bch_decoder_txn) mon2scb;

    function new(virtual bch_decoder_if.MON vif, mailbox #(bch_decoder_txn) mon2scb);
        if (vif == null)
            $fatal(1, "bch_decoder_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.o_valid === 1'b1)) begin
                bch_decoder_txn txn = new();

                txn.rx            = vif.cb_mon.rx_aligned;
                txn.err           = vif.cb_mon.o_err;
                txn.cw            = vif.cb_mon.o_cw;
                txn.msg           = vif.cb_mon.o_msg;
                txn.corrected     = vif.cb_mon.o_corrected;
                txn.uncorrectable = vif.cb_mon.o_uncorrectable;
                mon2scb.put(txn);
            end
        end
    endtask

endclass

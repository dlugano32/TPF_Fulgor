class bch_encoder_mon;

    virtual bch_encoder_if.MON vif;
    mailbox #(bch_encoder_txn) mon2scb;

    function new(virtual bch_encoder_if.MON vif, mailbox #(bch_encoder_txn) mon2scb);
        if (vif == null)
            $fatal(1, "bch_encoder_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.i_valid  === 1'b1)) begin
                bch_encoder_txn txn = new();

                txn.msg = vif.cb_mon.i_msg;
                txn.cw  = vif.cb_mon.o_cw;
                mon2scb.put(txn);
            end
        end
    endtask

endclass

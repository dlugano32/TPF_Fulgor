class tx_rx_top_mon;

    virtual tx_rx_top_if.MON vif;
    mailbox #(tx_rx_top_txn) mon2scb;

    function new(
        virtual tx_rx_top_if.MON vif,
        mailbox #(tx_rx_top_txn) mon2scb
    );
        if (vif == null)
            $fatal(1, "tx_rx_top_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.i_en === 1'b1)) begin
                tx_rx_top_txn txn = new();

                txn.locked      = vif.cb_mon.o_locked;
                txn.error_count = vif.cb_mon.o_error_count;
                txn.error_mask  = vif.cb_mon.error_mask;
                mon2scb.put(txn);
            end
        end
    endtask

endclass

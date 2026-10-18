class prbs31_mon;

    virtual prbs31_if.MON vif;
    mailbox #(prbs31_txn) mon2scb;

    function new(
        virtual prbs31_if.MON vif,
        mailbox #(prbs31_txn) mon2scb
    );
        if (vif == null)
            $fatal(1, "prbs31_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.i_en    === 1'b1)) begin
                prbs31_txn txn = new();

                txn.prbs = vif.cb_mon.o_prbs;
                mon2scb.put(txn);
            end
        end
    endtask

endclass

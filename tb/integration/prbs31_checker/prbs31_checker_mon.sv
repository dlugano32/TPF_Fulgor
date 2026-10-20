class prbs31_checker_mon;

    virtual prbs31_checker_if.MON vif;
    mailbox #(prbs31_checker_txn) mon2scb;

    function new(virtual prbs31_checker_if.MON vif, mailbox #(prbs31_checker_txn) mon2scb);
        if (vif == null)
            $fatal(1, "prbs31_checker_mon: vif is null");

        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(vif.cb_mon);

            if ((vif.cb_mon.i_rst_n === 1'b1) && (vif.cb_mon.i_checker_en === 1'b1)) begin
                prbs31_checker_txn frame = new();

                frame.generated_data = vif.cb_mon.checked_generated_data;
                frame.received_data  = vif.cb_mon.checked_received_data;
                frame.locked         = vif.cb_mon.o_locked;
                frame.error_count    = vif.cb_mon.o_error_count;
                mon2scb.put(frame);
            end
        end
    endtask

endclass

class prbs31_drv;

    virtual prbs31_if.DRV vif;
    mailbox #(prbs31_txn) gen2drv;
    mailbox #(prbs31_txn) drv2scb;

    bit done = 1'b0;

    function new(virtual prbs31_if.DRV vif, mailbox #(prbs31_txn) gen2drv, mailbox #(prbs31_txn) drv2scb);
        if (vif == null)
            $fatal(1, "prbs31_drv: vif is null");

        this.vif     = vif;
        this.gen2drv = gen2drv;
        this.drv2scb = drv2scb;
    endfunction

    task do_reset(seed_t seed, int unsigned reset_cycles = 3);
        vif.cb_drv.i_rst_n <= 1'b0;
        vif.cb_drv.i_en    <= 1'b0;
        vif.cb_drv.i_seed  <= seed;

        repeat (reset_cycles) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    task drive_test(prbs31_txn txn);
        drv2scb.put(txn);
        do_reset(txn.seed);

        @(vif.cb_drv) vif.cb_drv.i_en <= 1'b1;
        repeat (txn.cycles) @(vif.cb_drv);
        vif.cb_drv.i_en <= 1'b0;
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            prbs31_txn txn;

            gen2drv.get(txn);
            txn.display("DRV");
            drive_test(txn);
        end

        done = 1'b1;
    endtask

endclass

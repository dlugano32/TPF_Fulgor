class tx_rx_top_drv;

    import tx_rx_top_tb_pkg::*;

    virtual tx_rx_top_if.DRV vif;
    mailbox #(tx_rx_top_test_cfg) gen2drv;
    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;

    bit done = 1'b0;

    function new(
        virtual tx_rx_top_if.DRV vif,
        mailbox #(tx_rx_top_test_cfg) gen2drv,
        mailbox #(tx_rx_top_test_cfg) drv2scb_cfg
    );
        if (vif == null)
            $fatal(1, "tx_rx_top_drv: vif is null");

        this.vif         = vif;
        this.gen2drv     = gen2drv;
        this.drv2scb_cfg = drv2scb_cfg;
    endfunction

    task do_reset(seed_t seed);
        vif.cb_drv.i_rst_n <= 1'b0;
        vif.cb_drv.i_en    <= 1'b0;
        vif.cb_drv.i_seed  <= seed;

        repeat (RESET_CYCLES) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    task drive_test(tx_rx_top_test_cfg cfg);
        bit locked_seen = 1'b0;

        do_reset(cfg.seed);
        drv2scb_cfg.put(cfg);

        @(vif.cb_drv);
        vif.cb_drv.i_en <= 1'b1;

        for (int unsigned cycle = 0; cycle < LOCK_TIMEOUT; cycle++) begin
            @(vif.cb_drv);
            if (vif.cb_drv.o_locked === 1'b1) begin
                locked_seen = 1'b1;
                break;
            end
        end

        if (locked_seen)
            repeat (cfg.cycles) @(vif.cb_drv);

        vif.cb_drv.i_en <= 1'b0;
    endtask

    task run(int unsigned test_count);
        repeat (test_count) begin
            tx_rx_top_test_cfg cfg;

            gen2drv.get(cfg);
            drive_test(cfg);
        end

        done = 1'b1;
    endtask

endclass

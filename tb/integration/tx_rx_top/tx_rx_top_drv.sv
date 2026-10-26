class tx_rx_top_drv;

    import tx_rx_top_tb_pkg::*;

    virtual tx_rx_top_if.DRV vif;
    mailbox #(tx_rx_top_test_cfg) gen2drv;
    mailbox #(tx_rx_top_test_cfg) drv2scb_cfg;
    mailbox #(bit)               scb2drv_done;

    bit done = 1'b0;

    function new(
        virtual tx_rx_top_if.DRV vif,
        mailbox #(tx_rx_top_test_cfg) gen2drv,
        mailbox #(tx_rx_top_test_cfg) drv2scb_cfg,
        mailbox #(bit) scb2drv_done
    );
        if (vif == null)
            $fatal(1, "tx_rx_top_drv: vif is null");

        this.vif         = vif;
        this.gen2drv     = gen2drv;
        this.drv2scb_cfg = drv2scb_cfg;
        this.scb2drv_done = scb2drv_done;
    endfunction

    task do_reset(seed_t seed);
        vif.cb_drv.i_rst_n <= 1'b0;
        vif.cb_drv.i_en    <= 1'b0;
        vif.cb_drv.i_seed  <= seed;
        vif.cb_drv.error_mask <= '0;

        repeat (RESET_CYCLES) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    function automatic line_t get_burst_mask(tx_rx_top_test_cfg cfg, int unsigned cycle);
        line_t mask = '0;
        int unsigned burst_start;
        int unsigned burst_end;

        burst_start = PRE_BURST_CYCLES * LINE_W + cfg.burst_offset;
        burst_end   = burst_start + cfg.burst_length;

        for (int unsigned bit_index = 0; bit_index < LINE_W; bit_index++) begin
            int unsigned stream_position = cycle * LINE_W + bit_index;

            if ((stream_position >= burst_start) && (stream_position < burst_end))
                mask[bit_index] = 1'b1;
        end

        return mask;
    endfunction

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

        if (locked_seen) begin
            if (cfg.mode == CLEAN_TEST) begin
                repeat (cfg.cycles) @(vif.cb_drv);
            end else begin
                for (int unsigned cycle = 0; cycle < cfg.cycles; cycle++) begin
                    vif.cb_drv.error_mask <= get_burst_mask(cfg, cycle);
                    @(vif.cb_drv);
                end
            end
        end

        vif.cb_drv.i_en       <= 1'b0;
        vif.cb_drv.error_mask <= '0;
        // Wait for all valid checker results before resetting the next test.
        begin
            bit completed;
            scb2drv_done.get(completed);
        end
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

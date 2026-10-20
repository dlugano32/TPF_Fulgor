class prbs31_checker_drv;

    virtual prbs31_checker_if.DRV vif;
    mailbox #(prbs31_checker_test_cfg) gen2drv;
    mailbox #(prbs31_checker_test_cfg) drv2scb_cfg;
    mailbox #(prbs31_checker_txn)      drv2scb_frame;

    bit done = 1'b0;

    function new(
        virtual prbs31_checker_if.DRV vif,
        mailbox #(prbs31_checker_test_cfg) gen2drv,
        mailbox #(prbs31_checker_test_cfg) drv2scb_cfg,
        mailbox #(prbs31_checker_txn) drv2scb_frame
    );
        if (vif == null)
            $fatal(1, "prbs31_checker_drv: vif is null");

        this.vif           = vif;
        this.gen2drv       = gen2drv;
        this.drv2scb_cfg   = drv2scb_cfg;
        this.drv2scb_frame = drv2scb_frame;
    endfunction

    task do_reset(seed_t seed, int unsigned reset_cycles = 3);
        vif.cb_drv.i_rst_n      <= 1'b0;
        vif.cb_drv.i_prbs_en    <= 1'b0;
        vif.cb_drv.i_checker_en <= 1'b0;
        vif.cb_drv.i_seed       <= seed;
        vif.cb_drv.i_error_mask <= '0;

        repeat (reset_cycles) @(vif.cb_drv);
        vif.cb_drv.i_rst_n <= 1'b1;
    endtask

    function automatic error_mode_e get_error_mode(checker_scenario_e scenario, int unsigned frame_index);
        // Scenario-to-frame mapping:
        // CLEAN        : clean acquisition and clean traffic.
        // SEED_FAILURE : corrupt only frame 0, then retry acquisition cleanly.
        // FRAME_ERRORS : acquire with frame 0, then inject 1-10 errors/frame.
        case (scenario)
            CLEAN:        return NO_ERRORS;
            SEED_FAILURE: return (frame_index == 0) ? SEED_ERRORS : NO_ERRORS;
            FRAME_ERRORS: return (frame_index == 0) ? NO_ERRORS : RANDOM_ERRORS;
            default:      return NO_ERRORS;
        endcase
    endfunction

    task drive_test(prbs31_checker_test_cfg cfg);
        do_reset(cfg.seed);

        drv2scb_cfg.put(cfg);

        // Generate the first block before presenting a valid input to the checker.
        @(vif.cb_drv);
        vif.cb_drv.i_prbs_en <= 1'b1;
        @(vif.cb_drv);

        for (int unsigned frame_index = 0; frame_index < cfg.cycles; frame_index++) begin
            prbs31_checker_txn frame;
            error_mode_e error_mode;

            error_mode = get_error_mode(cfg.scenario, frame_index);
            frame = new(error_mode);

            if (!frame.randomize())
                $fatal(1,"Could not randomize error mask test=%0d frame=%0d",
                    cfg.test_index, frame_index
                );

            frame.scenario    = cfg.scenario;
            frame.test_index  = cfg.test_index;
            frame.frame_index = frame_index;

            drv2scb_frame.put(frame);

            vif.cb_drv.i_checker_en <= 1'b1;
            vif.cb_drv.i_error_mask <= frame.error_mask;
            @(vif.cb_drv);
        end

        vif.cb_drv.i_prbs_en    <= 1'b0;
        vif.cb_drv.i_checker_en <= 1'b0;
        vif.cb_drv.i_error_mask <= '0;
    endtask

    task run(int unsigned test_count);
        process current_process = process::self();

        current_process.srandom(RANDOM_SEED ^ 32'hE220_1231);

        repeat (test_count) begin
            prbs31_checker_test_cfg cfg;

            gen2drv.get(cfg);
            drive_test(cfg);
        end

        done = 1'b1;
    endtask

endclass

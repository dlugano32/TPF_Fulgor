class prbs31_checker_test_cfg;
    // One object describes a test.
    //
    // Producer: 
    //      prbs31_checker_gen sets scenario, randomizes seed/cycles, assigns test_index and sends the object through gen2drv.
    // Consumers: 
    //      prbs31_checker_drv reads it to reset and drive the test, then forwards the same configuration through drv2scb_cfg. 
    //      prbs31_checker_scb reads scenario/cycles/test_index to reset the C model and check all frames.
    
    import prbs31_checker_tb_pkg::*;

    rand seed_t       seed;
    rand int unsigned cycles;

    checker_scenario_e scenario;
    int unsigned       test_index;

    constraint seed_c {
        seed != '0;
    }

    constraint cycles_c {
        cycles inside {[MIN_FRAMES:MAX_FRAMES]};
    }

    function void display(string tag = "");
        $display("[%s] test=%0d scenario=%s seed=0x%08h cycles=%0d", 
        tag, test_index, scenario.name(), seed, cycles);
    endfunction

endclass

class prbs31_checker_txn;
    // This class is used for two different objects per checker-enabled frame;
    // driver and monitor do not fill the same instance.
    //
    // Expected object:
    //   prbs31_checker_drv sets error_mode, randomizes error_mask/n_errors, adds
    //   scenario/test/frame metadata and sends it through drv2scb_frame.
    //
    // Actual object:
    //   prbs31_checker_mon creates a separate object, fills generated_data,
    //   received_data, locked and error_count, and sends it through mon2scb.
    //
    // Consumer:
    //   prbs31_checker_scb gets one object from each mailbox in frame order and
    //   compares the intended injection against the aligned RTL observation.
    
    import prbs31_pkg::*;
    import prbs31_checker_tb_pkg::*;

    rand prbs_t       error_mask; // Filled only in the driver's expected object.
    rand int unsigned n_errors;   // Exact weight of error_mask.

    error_mode_e       error_mode; // Selects which constraint branch is active.
    checker_scenario_e scenario;   // Expected-object diagnostic metadata.
    int unsigned       test_index; // Expected-object diagnostic metadata.
    int unsigned       frame_index; // Drives per-frame scenario expectations.

    logic [P - 1 : 0] generated_data; // Filled only in the monitor's actual object.
    logic [P - 1 : 0] received_data;  // generated_data after error injection.
    logic             locked;         // RTL result aligned with received_data.
    logic [CNT_W - 1 : 0] error_count; // RTL result aligned with received_data.

    // Constraining the mask weight also makes all selected positions unique:
    // each active vector bit represents exactly one injected error.
    constraint errors_c {
        if (error_mode == NO_ERRORS) 
        {
            error_mask == '0;
            n_errors == 0;
        } else if (error_mode == SEED_ERRORS) 
        {
            n_errors inside {[1:10]};
            // seed_candidate is reconstructed from the first 31 temporal bits.
            error_mask[P - 1 : ORDER] == '0;
            $countones(error_mask[ORDER - 1 : 0]) == n_errors;
        } else 
        {
            n_errors inside {[1:10]};
            $countones(error_mask) == n_errors;
        }
    }

    function new(error_mode_e error_mode = NO_ERRORS);
        this.error_mode = error_mode;
    endfunction

endclass

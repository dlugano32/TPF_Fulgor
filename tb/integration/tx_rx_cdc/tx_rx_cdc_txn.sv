class tx_rx_cdc_test_cfg;

    rand seed_t       seed;
    rand int unsigned cycles;
    rand int unsigned burst_offset;
    rand int unsigned burst_delay;
    test_mode_e       mode;
    int unsigned      burst_length;
    int unsigned      test_index;

    constraint seed_c {
        seed != '0;
    }

    constraint cycles_c {
        if (mode == CLEAN_TEST)
            cycles inside {[MIN_CYCLES:MAX_CYCLES]};
        else
            cycles == POST_BURST_CYCLES;
    }

    constraint burst_c {
        burst_offset inside {[0:DSP_W-1]};
        burst_delay inside {[4:16]};
    }

    function void display(string tag = "");
        $display("[%s] mode=%s test=%0d seed=0x%08h cycles=%0d burst_length=%0d dsp_offset=%0d dsp_delay=%0d",
            tag, (mode == CLEAN_TEST) ? "CLEAN" : "BURST", test_index, seed, cycles, burst_length, burst_offset, burst_delay);
    endfunction

endclass

class tx_rx_cdc_txn;

    logic                 locked;
    logic [CNT_W - 1 : 0] error_count;
    logic                 valid;
    logic                 injection_done;

endclass

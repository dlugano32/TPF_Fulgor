class prbs31_txn;

    rand seed_t       seed;
    rand int unsigned cycles;

    logic [P - 1 : 0] prbs;
    int unsigned      test_index;

    constraint seed_c {
        seed != '0;
    }

    constraint cycles_c {
        cycles inside {[100:1000]};
    }

    function void display(string tag = "");
        $display("[%s] test=%0d seed=0x%08h cycles=%0d", tag, test_index, seed, cycles);
    endfunction

endclass

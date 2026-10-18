class prbs31_gen;

    mailbox #(prbs31_txn) gen2drv;

    function new(mailbox #(prbs31_txn) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run(int unsigned test_count);
        for (int test_index = 0; test_index < test_count; test_index++) begin
            prbs31_txn txn = new();

            if (!txn.randomize())
                $fatal(1, "Could not randomize PRBS31 test %0d", test_index);

            txn.test_index = test_index;
            txn.display("GEN");
            gen2drv.put(txn);
        end
    endtask

endclass

class bch_encoder_gen;

    mailbox #(bch_encoder_txn) gen2drv;


    function new(mailbox #(bch_encoder_txn) gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task send_message(msg_t msg);
        bch_encoder_txn txn = new();

        txn.msg = msg;
        gen2drv.put(txn);
    endtask

    task run(int unsigned n_random);
        msg_t msg;

        send_message('0);
        send_message('1);

        for (int bit_index = 0; bit_index < K; bit_index++) begin
            msg = '0;
            msg[bit_index] = 1'b1;
            send_message(msg);
        end

        repeat (n_random) begin
            bch_encoder_txn txn = new();

            if (!txn.randomize())
                $fatal(1, "Could not randomize BCH encoder transaction");

            gen2drv.put(txn);
        end

    endtask

endclass

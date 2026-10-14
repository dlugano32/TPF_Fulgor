    class bch_encoder_scb;

    mailbox #(bch_encoder_txn) mon2scb;

    int unsigned checked_count = 0;
    int unsigned error_count   = 0;
    bit          done          = 0;

    function new(mailbox #(bch_encoder_txn) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run(int unsigned transaction_count);
        repeat (transaction_count) begin
            bch_encoder_txn actual;
            cw_t expected;

            mon2scb.get(actual);

            actual.display($sformatf("SCB sample=%0d", checked_count));

            bch_encode_dpi(actual.msg, expected);

            if (actual.cw !== expected) begin
                $error(
                    "Mismatch sample=%0d msg=0x%029h expected=0x%032h actual=0x%032h",
                    checked_count,
                    actual.msg,
                    expected,
                    actual.cw
                );
                error_count++;
            end

            checked_count++;
        end

        done = 1'b1;
    endtask

endclass

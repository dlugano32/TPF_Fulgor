class bch_decoder_scb;

    mailbox #(bch_decoder_txn) mon2scb;

    int unsigned checked_count = 0;
    int unsigned error_count   = 0;
    bit          done          = 0;

    function new(mailbox #(bch_decoder_txn) mon2scb);
        this.mon2scb = mon2scb;
    endfunction

    task run(int unsigned transaction_count);
        repeat (transaction_count) begin
            bch_decoder_txn actual;
            cw_t  expected_err;
            cw_t  expected_cw;
            msg_t expected_msg;
            bit   expected_corrected;
            bit   expected_uncorrectable;

            mon2scb.get(actual);

            bch_decode_dpi(
                actual.rx,
                expected_err,
                expected_cw,
                expected_msg,
                expected_corrected,
                expected_uncorrectable
            );

            if ((actual.err           !== expected_err) ||
                (actual.cw            !== expected_cw) ||
                (actual.msg           !== expected_msg) ||
                (actual.corrected     !== expected_corrected) ||
                (actual.uncorrectable !== expected_uncorrectable)) begin
                    
                $error("BCH decoder mismatch sample=%0d", checked_count);
                actual.display("actual");
                $display(
                    "[expected] rx=0x%032h err=0x%032h cw=0x%032h msg=0x%029h corrected=%0b uncorrectable=%0b",
                    actual.rx,
                    expected_err,
                    expected_cw,
                    expected_msg,
                    expected_corrected,
                    expected_uncorrectable
                );
                error_count++;
            end

            checked_count++;
        end

        done = 1'b1;
    endtask

endclass

class bch_encoder_txn;

    rand msg_t msg;
    cw_t cw;

    function void display(string tag = "");
        $display("[%s] msg=0x%029h cw=0x%032h", tag, msg, cw);
    endfunction

endclass

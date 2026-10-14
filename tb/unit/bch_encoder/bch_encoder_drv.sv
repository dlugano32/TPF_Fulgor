class bch_encoder_drv;

    virtual bch_encoder_if.DRV vif;
    mailbox #(bch_encoder_txn) gen2drv;

    bit done = 0;

    function new(virtual bch_encoder_if.DRV vif, mailbox #(bch_encoder_txn) gen2drv);
        if (vif == null)
            $fatal(1, "bch_encoder_drv: vif is null");

        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task do_reset(int unsigned cycles = 3);
        vif.cb_drv.i_arst_n <= 1'b0;
        vif.cb_drv.i_msg   <= '0;
        vif.cb_drv.i_valid <= '0;

        repeat (cycles) @(vif.cb_drv);
        vif.cb_drv.i_arst_n <= 1'b1;
    endtask

    task run(int unsigned txn_count);
        bch_encoder_txn txn;

        do_reset();

        repeat (txn_count) begin
            gen2drv.get(txn);
            @(vif.cb_drv);
            vif.cb_drv.i_msg   <= txn.msg;
            vif.cb_drv.i_valid <= 1'b1;
        end

        // Esperamos que el monitor vea el último codeword antes de terminar
        @(vif.cb_drv);
        vif.cb_drv.i_msg   <= '0;
        vif.cb_drv.i_valid <= '0;
        done = 1'b1;

    endtask

endclass

`timescale 1ps/1ps

module prbs31_checker_tb;

    import prbs31_pkg::*;
    import prbs31_checker_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    prbs31_checker_if vif (clk);
    
    // Preserve the input consumed by the checker for the monitor to compare against the outputs
    // At the same edge, the generator updates generated_data with the following PRBS block
    always_ff @(posedge clk) begin
        if (!vif.i_rst_n) begin
            vif.checked_generated_data <= '0;
            vif.checked_received_data  <= '0;
        end else if (vif.i_checker_en) begin
            vif.checked_generated_data <= vif.generated_data;
            vif.checked_received_data  <= vif.received_data;
        end
    end

    assign vif.received_data = vif.generated_data ^ vif.i_error_mask;

    prbs31 u_prbs31 (
        .i_clk   (clk),
        .i_rst_n (vif.i_rst_n),
        .i_en    (vif.i_prbs_en),
        .i_seed  (vif.i_seed),
        .o_prbs  (vif.generated_data)
    );

    prbs31_checker u_prbs31_checker (
        .i_clk         (clk),
        .i_rst_n       (vif.i_rst_n),
        .i_en          (vif.i_checker_en),
        .i_data        (vif.received_data),
        .o_locked      (vif.o_locked),
        .o_error_count (vif.o_error_count),
        .o_valid       (vif.o_valid)
    );

    prbs31_checker_program u_tb (vif);

endmodule

program automatic prbs31_checker_program (prbs31_checker_if vif);

    import prbs31_checker_tb_pkg::*;

    prbs31_checker_env env;

    initial begin
        $display("");
        $display("=== PRBS31 checker integration simulation started ===");

        env = new(vif);
        env.run();

        $display("=== PRBS31 checker integration simulation finished ===");
        $display("");
        $finish;
    end

endprogram

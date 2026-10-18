`timescale 1ps/1ps

module prbs31_tb;

    import prbs31_pkg::*;
    import prbs31_tb_pkg::*;

    localparam time CLK_PERIOD = 10ns;

    logic clk = 1'b0;
    always #(CLK_PERIOD / 2) clk = ~clk;

    prbs31_if vif (clk);

    prbs31 u_prbs31 (
        .i_clk   (clk),
        .i_rst_n (vif.i_rst_n),
        .i_en    (vif.i_en),
        .i_seed  (vif.i_seed),
        .o_prbs  (vif.o_prbs)
    );

    prbs31_program u_tb (vif);

endmodule

program automatic prbs31_program (prbs31_if vif);

    import prbs31_tb_pkg::*;

    prbs31_env env;

    initial begin
        $display("");
        $display("=== PRBS31 simulation started ===");

        env = new(vif);
        env.run();

        $display("=== PRBS31 simulation finished ===");
        $display("");
        $finish;
    end

endprogram

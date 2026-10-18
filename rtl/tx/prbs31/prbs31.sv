`timescale 1ps/1ps

module prbs31 
    import prbs31_pkg::*;
(
    input logic i_clk,
    input logic i_rst_n,
    input logic i_en,
    input logic [ORDER - 1 : 0] i_seed,

    output logic [P - 1 : 0] o_prbs

);
    logic [ORDER - 1 : 0] lfsr_r;
    logic [ORDER - 1 : 0] lfsr_next;

    logic [P - 1 : 0] prbs_r;
    logic [P - 1 : 0] prbs_next;

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            lfsr_r <= i_seed;
        end else if (i_en) begin
            lfsr_r <= lfsr_next;
        end
    end

    prbs31_mult_a
    u_prbs31_mult_a (
        .i_state(lfsr_r),
        .o_state_next(lfsr_next)
    );

    prbs31_mult_b
    u_prbs31_mult_b (
        .i_state(lfsr_r),
        .o_prbs(prbs_next)
    );

    always_ff @(posedge i_clk) begin
        if(!i_rst_n) begin
            prbs_r <= '0;
        end else if (i_en) begin
            prbs_r <= prbs_next;
        end
    end

    assign o_prbs = prbs_r;

endmodule
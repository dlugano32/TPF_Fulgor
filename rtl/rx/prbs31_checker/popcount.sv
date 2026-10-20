`timescale 1ps/1ps

module popcount #(
    parameter int WIDTH = 32,
    localparam int CNT_W = $clog2(WIDTH + 1)
) (
    input  logic [WIDTH - 1 : 0] i_vec,
    output logic [CNT_W - 1 : 0] o_weight
);

    always_comb begin
        o_weight = '0;

        for (int ix = 0; ix < WIDTH; ix++) begin
            o_weight = o_weight + i_vec[ix];
        end
    end

endmodule

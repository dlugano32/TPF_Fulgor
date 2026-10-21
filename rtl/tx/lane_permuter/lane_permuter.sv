`timescale 1ps/1ps

module lane_permuter #(
    parameter  int LANES  = 7,
    parameter  int CW_W   = 127,
    localparam int LINE_W = LANES * CW_W
) (
    input  logic [LANES   - 1 : 0][CW_W - 1 : 0] i_codewords,
    output logic [LINE_W  - 1 : 0]               o_line
);

    generate
        for(genvar bit_idx = 0; bit_idx < CW_W; bit_idx++) begin : gen_bits
            for(genvar lane = 0; lane < LANES; lane++) begin : gen_lanes
                assign o_line[lane + bit_idx*LANES] = i_codewords[lane][bit_idx];
            end
        end
    endgenerate

endmodule
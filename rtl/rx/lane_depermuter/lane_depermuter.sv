`timescale 1ps/1ps

module lane_depermuter #(
    parameter  int LANES  = 7,
    parameter  int CW_W   = 127,
    localparam int LINE_W = LANES * CW_W
) (
    input  logic [LINE_W  - 1 : 0]               i_line,
    output logic [LANES   - 1 : 0][CW_W - 1 : 0] o_codewords
);

    generate
        for(genvar lane = 0; lane < LANES; lane++) begin : gen_lanes
            for(genvar bit_idx = 0; bit_idx < CW_W; bit_idx++) begin : gen_bits
                assign o_codewords[lane][bit_idx] = i_line[lane + bit_idx*LANES];
            end
        end
    endgenerate

endmodule
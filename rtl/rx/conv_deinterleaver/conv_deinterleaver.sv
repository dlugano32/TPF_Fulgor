`timescale 1ps/1ps

module conv_deinterleaver #(
    parameter int D = 1,
    parameter int B = 8,
    parameter int LINE_W = 889
) (
    input  logic                   i_clk,
    input  logic                   i_rst_n,
    input  logic                   i_en,
    input  logic [LINE_W  - 1 : 0] i_line,
    output logic [LINE_W  - 1 : 0] o_line
);
    
    generate
        for(genvar i=0; i<LINE_W; i++) begin : gen_bit
            localparam int DELAY = (B-1 -(i%B)) *D;  // Generates the delay for each input bit

            if(DELAY == 0) begin : gen_bit_direct // Bits from branch B-1 pass directly
                assign o_line[i] = i_line[i];       
            end else begin : gen_bit_delayed // Bits from other branches are delayed according to its bit number

                logic [DELAY - 1 : 0] history;

                always_ff @(posedge i_clk) begin
                    if(!i_rst_n) begin
                        history <= '0;
                    end else if (i_en) begin
                        history[0] <= i_line[i];

                        for(int j=1; j<DELAY; j++) begin
                            history[j] <= history[j-1];
                        end
                    end
                end
                assign o_line[i] = history[DELAY-1];
            end
        end
    endgenerate

endmodule

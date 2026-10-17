`timescale 1ps/1ps

module gf127_log_lut # (
    localparam int M = 7
) (
    input  logic [M - 1 : 0] i_element,
    output logic [M - 1 : 0] o_logarithm
);

    always_comb begin : log_lut
        o_logarithm = 7'd0;
        case (i_element)
            7'h00: o_logarithm = 7'd0; // log_alpha(0) no esta definido
            7'h01: o_logarithm = 7'd0;
            7'h02: o_logarithm = 7'd1;
            7'h03: o_logarithm = 7'd31;
            7'h04: o_logarithm = 7'd2;
            7'h05: o_logarithm = 7'd62;
            7'h06: o_logarithm = 7'd32;
            7'h07: o_logarithm = 7'd103;
            7'h08: o_logarithm = 7'd3;
            7'h09: o_logarithm = 7'd7;
            7'h0A: o_logarithm = 7'd63;
            7'h0B: o_logarithm = 7'd15;
            7'h0C: o_logarithm = 7'd33;
            7'h0D: o_logarithm = 7'd84;
            7'h0E: o_logarithm = 7'd104;
            7'h0F: o_logarithm = 7'd93;
            7'h10: o_logarithm = 7'd4;
            7'h11: o_logarithm = 7'd124;
            7'h12: o_logarithm = 7'd8;
            7'h13: o_logarithm = 7'd121;
            7'h14: o_logarithm = 7'd64;
            7'h15: o_logarithm = 7'd79;
            7'h16: o_logarithm = 7'd16;
            7'h17: o_logarithm = 7'd115;
            7'h18: o_logarithm = 7'd34;
            7'h19: o_logarithm = 7'd11;
            7'h1A: o_logarithm = 7'd85;
            7'h1B: o_logarithm = 7'd38;
            7'h1C: o_logarithm = 7'd105;
            7'h1D: o_logarithm = 7'd46;
            7'h1E: o_logarithm = 7'd94;
            7'h1F: o_logarithm = 7'd51;
            7'h20: o_logarithm = 7'd5;
            7'h21: o_logarithm = 7'd82;
            7'h22: o_logarithm = 7'd125;
            7'h23: o_logarithm = 7'd60;
            7'h24: o_logarithm = 7'd9;
            7'h25: o_logarithm = 7'd44;
            7'h26: o_logarithm = 7'd122;
            7'h27: o_logarithm = 7'd77;
            7'h28: o_logarithm = 7'd65;
            7'h29: o_logarithm = 7'd67;
            7'h2A: o_logarithm = 7'd80;
            7'h2B: o_logarithm = 7'd42;
            7'h2C: o_logarithm = 7'd17;
            7'h2D: o_logarithm = 7'd69;
            7'h2E: o_logarithm = 7'd116;
            7'h2F: o_logarithm = 7'd23;
            7'h30: o_logarithm = 7'd35;
            7'h31: o_logarithm = 7'd118;
            7'h32: o_logarithm = 7'd12;
            7'h33: o_logarithm = 7'd28;
            7'h34: o_logarithm = 7'd86;
            7'h35: o_logarithm = 7'd25;
            7'h36: o_logarithm = 7'd39;
            7'h37: o_logarithm = 7'd57;
            7'h38: o_logarithm = 7'd106;
            7'h39: o_logarithm = 7'd19;
            7'h3A: o_logarithm = 7'd47;
            7'h3B: o_logarithm = 7'd89;
            7'h3C: o_logarithm = 7'd95;
            7'h3D: o_logarithm = 7'd71;
            7'h3E: o_logarithm = 7'd52;
            7'h3F: o_logarithm = 7'd110;
            7'h40: o_logarithm = 7'd6;
            7'h41: o_logarithm = 7'd14;
            7'h42: o_logarithm = 7'd83;
            7'h43: o_logarithm = 7'd92;
            7'h44: o_logarithm = 7'd126;
            7'h45: o_logarithm = 7'd30;
            7'h46: o_logarithm = 7'd61;
            7'h47: o_logarithm = 7'd102;
            7'h48: o_logarithm = 7'd10;
            7'h49: o_logarithm = 7'd37;
            7'h4A: o_logarithm = 7'd45;
            7'h4B: o_logarithm = 7'd50;
            7'h4C: o_logarithm = 7'd123;
            7'h4D: o_logarithm = 7'd120;
            7'h4E: o_logarithm = 7'd78;
            7'h4F: o_logarithm = 7'd114;
            7'h50: o_logarithm = 7'd66;
            7'h51: o_logarithm = 7'd41;
            7'h52: o_logarithm = 7'd68;
            7'h53: o_logarithm = 7'd22;
            7'h54: o_logarithm = 7'd81;
            7'h55: o_logarithm = 7'd59;
            7'h56: o_logarithm = 7'd43;
            7'h57: o_logarithm = 7'd76;
            7'h58: o_logarithm = 7'd18;
            7'h59: o_logarithm = 7'd88;
            7'h5A: o_logarithm = 7'd70;
            7'h5B: o_logarithm = 7'd109;
            7'h5C: o_logarithm = 7'd117;
            7'h5D: o_logarithm = 7'd27;
            7'h5E: o_logarithm = 7'd24;
            7'h5F: o_logarithm = 7'd56;
            7'h60: o_logarithm = 7'd36;
            7'h61: o_logarithm = 7'd49;
            7'h62: o_logarithm = 7'd119;
            7'h63: o_logarithm = 7'd113;
            7'h64: o_logarithm = 7'd13;
            7'h65: o_logarithm = 7'd91;
            7'h66: o_logarithm = 7'd29;
            7'h67: o_logarithm = 7'd101;
            7'h68: o_logarithm = 7'd87;
            7'h69: o_logarithm = 7'd108;
            7'h6A: o_logarithm = 7'd26;
            7'h6B: o_logarithm = 7'd55;
            7'h6C: o_logarithm = 7'd40;
            7'h6D: o_logarithm = 7'd21;
            7'h6E: o_logarithm = 7'd58;
            7'h6F: o_logarithm = 7'd75;
            7'h70: o_logarithm = 7'd107;
            7'h71: o_logarithm = 7'd54;
            7'h72: o_logarithm = 7'd20;
            7'h73: o_logarithm = 7'd74;
            7'h74: o_logarithm = 7'd48;
            7'h75: o_logarithm = 7'd112;
            7'h76: o_logarithm = 7'd90;
            7'h77: o_logarithm = 7'd100;
            7'h78: o_logarithm = 7'd96;
            7'h79: o_logarithm = 7'd97;
            7'h7A: o_logarithm = 7'd72;
            7'h7B: o_logarithm = 7'd98;
            7'h7C: o_logarithm = 7'd53;
            7'h7D: o_logarithm = 7'd73;
            7'h7E: o_logarithm = 7'd111;
            7'h7F: o_logarithm = 7'd99;
            default: o_logarithm = 7'd0;
        endcase 
    end

endmodule
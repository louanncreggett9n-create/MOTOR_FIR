`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: coef_rom_b
// Description:
//     Self-contained 128-point Goertzel coefficient ROM.
//     The values are generated from the delivered .mem files.
//////////////////////////////////////////////////////////////////////////////////

module coef_rom_b #(
    parameter integer ADDR_W = 8,
    parameter integer COEF_W = 18
)(
    input  wire [ADDR_W-1:0]        addr,
    output reg signed [COEF_W-1:0] c,
    output reg signed [COEF_W-1:0] cos_w,
    output reg signed [COEF_W-1:0] sin_w
);

    always @(*)
    begin
        case(addr)
            8'd0: begin c = 18'sh08000; cos_w = 18'sh04000; sin_w = 18'sh00000; end
            8'd1: begin c = 18'sh07ff6; cos_w = 18'sh03ffb; sin_w = 18'sh00192; end
            8'd2: begin c = 18'sh07fd9; cos_w = 18'sh03fec; sin_w = 18'sh00324; end
            8'd3: begin c = 18'sh07fa7; cos_w = 18'sh03fd4; sin_w = 18'sh004b5; end
            8'd4: begin c = 18'sh07f62; cos_w = 18'sh03fb1; sin_w = 18'sh00646; end
            8'd5: begin c = 18'sh07f0a; cos_w = 18'sh03f85; sin_w = 18'sh007d6; end
            8'd6: begin c = 18'sh07e9d; cos_w = 18'sh03f4f; sin_w = 18'sh00964; end
            8'd7: begin c = 18'sh07e1e; cos_w = 18'sh03f0f; sin_w = 18'sh00af1; end
            8'd8: begin c = 18'sh07d8a; cos_w = 18'sh03ec5; sin_w = 18'sh00c7c; end
            8'd9: begin c = 18'sh07ce4; cos_w = 18'sh03e72; sin_w = 18'sh00e06; end
            8'd10: begin c = 18'sh07c2a; cos_w = 18'sh03e15; sin_w = 18'sh00f8d; end
            8'd11: begin c = 18'sh07b5d; cos_w = 18'sh03daf; sin_w = 18'sh01112; end
            8'd12: begin c = 18'sh07a7d; cos_w = 18'sh03d3f; sin_w = 18'sh01294; end
            8'd13: begin c = 18'sh0798a; cos_w = 18'sh03cc5; sin_w = 18'sh01413; end
            8'd14: begin c = 18'sh07885; cos_w = 18'sh03c42; sin_w = 18'sh01590; end
            8'd15: begin c = 18'sh0776c; cos_w = 18'sh03bb6; sin_w = 18'sh01709; end
            8'd16: begin c = 18'sh07642; cos_w = 18'sh03b21; sin_w = 18'sh0187e; end
            8'd17: begin c = 18'sh07505; cos_w = 18'sh03a82; sin_w = 18'sh019ef; end
            8'd18: begin c = 18'sh073b6; cos_w = 18'sh039db; sin_w = 18'sh01b5d; end
            8'd19: begin c = 18'sh07255; cos_w = 18'sh0392b; sin_w = 18'sh01cc6; end
            8'd20: begin c = 18'sh070e3; cos_w = 18'sh03871; sin_w = 18'sh01e2b; end
            8'd21: begin c = 18'sh06f5f; cos_w = 18'sh037b0; sin_w = 18'sh01f8c; end
            8'd22: begin c = 18'sh06dca; cos_w = 18'sh036e5; sin_w = 18'sh020e7; end
            8'd23: begin c = 18'sh06c24; cos_w = 18'sh03612; sin_w = 18'sh0223d; end
            8'd24: begin c = 18'sh06a6e; cos_w = 18'sh03537; sin_w = 18'sh0238e; end
            8'd25: begin c = 18'sh068a7; cos_w = 18'sh03453; sin_w = 18'sh024da; end
            8'd26: begin c = 18'sh066d0; cos_w = 18'sh03368; sin_w = 18'sh02620; end
            8'd27: begin c = 18'sh064e9; cos_w = 18'sh03274; sin_w = 18'sh02760; end
            8'd28: begin c = 18'sh062f2; cos_w = 18'sh03179; sin_w = 18'sh0289a; end
            8'd29: begin c = 18'sh060ec; cos_w = 18'sh03076; sin_w = 18'sh029ce; end
            8'd30: begin c = 18'sh05ed7; cos_w = 18'sh02f6c; sin_w = 18'sh02afb; end
            8'd31: begin c = 18'sh05cb4; cos_w = 18'sh02e5a; sin_w = 18'sh02c21; end
            8'd32: begin c = 18'sh05a82; cos_w = 18'sh02d41; sin_w = 18'sh02d41; end
            8'd33: begin c = 18'sh05843; cos_w = 18'sh02c21; sin_w = 18'sh02e5a; end
            8'd34: begin c = 18'sh055f6; cos_w = 18'sh02afb; sin_w = 18'sh02f6c; end
            8'd35: begin c = 18'sh0539b; cos_w = 18'sh029ce; sin_w = 18'sh03076; end
            8'd36: begin c = 18'sh05134; cos_w = 18'sh0289a; sin_w = 18'sh03179; end
            8'd37: begin c = 18'sh04ec0; cos_w = 18'sh02760; sin_w = 18'sh03274; end
            8'd38: begin c = 18'sh04c40; cos_w = 18'sh02620; sin_w = 18'sh03368; end
            8'd39: begin c = 18'sh049b4; cos_w = 18'sh024da; sin_w = 18'sh03453; end
            8'd40: begin c = 18'sh0471d; cos_w = 18'sh0238e; sin_w = 18'sh03537; end
            8'd41: begin c = 18'sh0447b; cos_w = 18'sh0223d; sin_w = 18'sh03612; end
            8'd42: begin c = 18'sh041ce; cos_w = 18'sh020e7; sin_w = 18'sh036e5; end
            8'd43: begin c = 18'sh03f17; cos_w = 18'sh01f8c; sin_w = 18'sh037b0; end
            8'd44: begin c = 18'sh03c57; cos_w = 18'sh01e2b; sin_w = 18'sh03871; end
            8'd45: begin c = 18'sh0398d; cos_w = 18'sh01cc6; sin_w = 18'sh0392b; end
            8'd46: begin c = 18'sh036ba; cos_w = 18'sh01b5d; sin_w = 18'sh039db; end
            8'd47: begin c = 18'sh033df; cos_w = 18'sh019ef; sin_w = 18'sh03a82; end
            8'd48: begin c = 18'sh030fc; cos_w = 18'sh0187e; sin_w = 18'sh03b21; end
            8'd49: begin c = 18'sh02e11; cos_w = 18'sh01709; sin_w = 18'sh03bb6; end
            8'd50: begin c = 18'sh02b1f; cos_w = 18'sh01590; sin_w = 18'sh03c42; end
            8'd51: begin c = 18'sh02827; cos_w = 18'sh01413; sin_w = 18'sh03cc5; end
            8'd52: begin c = 18'sh02528; cos_w = 18'sh01294; sin_w = 18'sh03d3f; end
            8'd53: begin c = 18'sh02224; cos_w = 18'sh01112; sin_w = 18'sh03daf; end
            8'd54: begin c = 18'sh01f1a; cos_w = 18'sh00f8d; sin_w = 18'sh03e15; end
            8'd55: begin c = 18'sh01c0c; cos_w = 18'sh00e06; sin_w = 18'sh03e72; end
            8'd56: begin c = 18'sh018f9; cos_w = 18'sh00c7c; sin_w = 18'sh03ec5; end
            8'd57: begin c = 18'sh015e2; cos_w = 18'sh00af1; sin_w = 18'sh03f0f; end
            8'd58: begin c = 18'sh012c8; cos_w = 18'sh00964; sin_w = 18'sh03f4f; end
            8'd59: begin c = 18'sh00fab; cos_w = 18'sh007d6; sin_w = 18'sh03f85; end
            8'd60: begin c = 18'sh00c8c; cos_w = 18'sh00646; sin_w = 18'sh03fb1; end
            8'd61: begin c = 18'sh0096b; cos_w = 18'sh004b5; sin_w = 18'sh03fd4; end
            8'd62: begin c = 18'sh00648; cos_w = 18'sh00324; sin_w = 18'sh03fec; end
            8'd63: begin c = 18'sh00324; cos_w = 18'sh00192; sin_w = 18'sh03ffb; end
            8'd64: begin c = 18'sh00000; cos_w = 18'sh00000; sin_w = 18'sh04000; end
            8'd65: begin c = 18'sh3fcdc; cos_w = 18'sh3fe6e; sin_w = 18'sh03ffb; end
            8'd66: begin c = 18'sh3f9b8; cos_w = 18'sh3fcdc; sin_w = 18'sh03fec; end
            8'd67: begin c = 18'sh3f695; cos_w = 18'sh3fb4b; sin_w = 18'sh03fd4; end
            8'd68: begin c = 18'sh3f374; cos_w = 18'sh3f9ba; sin_w = 18'sh03fb1; end
            8'd69: begin c = 18'sh3f055; cos_w = 18'sh3f82a; sin_w = 18'sh03f85; end
            8'd70: begin c = 18'sh3ed38; cos_w = 18'sh3f69c; sin_w = 18'sh03f4f; end
            8'd71: begin c = 18'sh3ea1e; cos_w = 18'sh3f50f; sin_w = 18'sh03f0f; end
            8'd72: begin c = 18'sh3e707; cos_w = 18'sh3f384; sin_w = 18'sh03ec5; end
            8'd73: begin c = 18'sh3e3f4; cos_w = 18'sh3f1fa; sin_w = 18'sh03e72; end
            8'd74: begin c = 18'sh3e0e6; cos_w = 18'sh3f073; sin_w = 18'sh03e15; end
            8'd75: begin c = 18'sh3dddc; cos_w = 18'sh3eeee; sin_w = 18'sh03daf; end
            8'd76: begin c = 18'sh3dad8; cos_w = 18'sh3ed6c; sin_w = 18'sh03d3f; end
            8'd77: begin c = 18'sh3d7d9; cos_w = 18'sh3ebed; sin_w = 18'sh03cc5; end
            8'd78: begin c = 18'sh3d4e1; cos_w = 18'sh3ea70; sin_w = 18'sh03c42; end
            8'd79: begin c = 18'sh3d1ef; cos_w = 18'sh3e8f7; sin_w = 18'sh03bb6; end
            8'd80: begin c = 18'sh3cf04; cos_w = 18'sh3e782; sin_w = 18'sh03b21; end
            8'd81: begin c = 18'sh3cc21; cos_w = 18'sh3e611; sin_w = 18'sh03a82; end
            8'd82: begin c = 18'sh3c946; cos_w = 18'sh3e4a3; sin_w = 18'sh039db; end
            8'd83: begin c = 18'sh3c673; cos_w = 18'sh3e33a; sin_w = 18'sh0392b; end
            8'd84: begin c = 18'sh3c3a9; cos_w = 18'sh3e1d5; sin_w = 18'sh03871; end
            8'd85: begin c = 18'sh3c0e9; cos_w = 18'sh3e074; sin_w = 18'sh037b0; end
            8'd86: begin c = 18'sh3be32; cos_w = 18'sh3df19; sin_w = 18'sh036e5; end
            8'd87: begin c = 18'sh3bb85; cos_w = 18'sh3ddc3; sin_w = 18'sh03612; end
            8'd88: begin c = 18'sh3b8e3; cos_w = 18'sh3dc72; sin_w = 18'sh03537; end
            8'd89: begin c = 18'sh3b64c; cos_w = 18'sh3db26; sin_w = 18'sh03453; end
            8'd90: begin c = 18'sh3b3c0; cos_w = 18'sh3d9e0; sin_w = 18'sh03368; end
            8'd91: begin c = 18'sh3b140; cos_w = 18'sh3d8a0; sin_w = 18'sh03274; end
            8'd92: begin c = 18'sh3aecc; cos_w = 18'sh3d766; sin_w = 18'sh03179; end
            8'd93: begin c = 18'sh3ac65; cos_w = 18'sh3d632; sin_w = 18'sh03076; end
            8'd94: begin c = 18'sh3aa0a; cos_w = 18'sh3d505; sin_w = 18'sh02f6c; end
            8'd95: begin c = 18'sh3a7bd; cos_w = 18'sh3d3df; sin_w = 18'sh02e5a; end
            8'd96: begin c = 18'sh3a57e; cos_w = 18'sh3d2bf; sin_w = 18'sh02d41; end
            8'd97: begin c = 18'sh3a34c; cos_w = 18'sh3d1a6; sin_w = 18'sh02c21; end
            8'd98: begin c = 18'sh3a129; cos_w = 18'sh3d094; sin_w = 18'sh02afb; end
            8'd99: begin c = 18'sh39f14; cos_w = 18'sh3cf8a; sin_w = 18'sh029ce; end
            8'd100: begin c = 18'sh39d0e; cos_w = 18'sh3ce87; sin_w = 18'sh0289a; end
            8'd101: begin c = 18'sh39b17; cos_w = 18'sh3cd8c; sin_w = 18'sh02760; end
            8'd102: begin c = 18'sh39930; cos_w = 18'sh3cc98; sin_w = 18'sh02620; end
            8'd103: begin c = 18'sh39759; cos_w = 18'sh3cbad; sin_w = 18'sh024da; end
            8'd104: begin c = 18'sh39592; cos_w = 18'sh3cac9; sin_w = 18'sh0238e; end
            8'd105: begin c = 18'sh393dc; cos_w = 18'sh3c9ee; sin_w = 18'sh0223d; end
            8'd106: begin c = 18'sh39236; cos_w = 18'sh3c91b; sin_w = 18'sh020e7; end
            8'd107: begin c = 18'sh390a1; cos_w = 18'sh3c850; sin_w = 18'sh01f8c; end
            8'd108: begin c = 18'sh38f1d; cos_w = 18'sh3c78f; sin_w = 18'sh01e2b; end
            8'd109: begin c = 18'sh38dab; cos_w = 18'sh3c6d5; sin_w = 18'sh01cc6; end
            8'd110: begin c = 18'sh38c4a; cos_w = 18'sh3c625; sin_w = 18'sh01b5d; end
            8'd111: begin c = 18'sh38afb; cos_w = 18'sh3c57e; sin_w = 18'sh019ef; end
            8'd112: begin c = 18'sh389be; cos_w = 18'sh3c4df; sin_w = 18'sh0187e; end
            8'd113: begin c = 18'sh38894; cos_w = 18'sh3c44a; sin_w = 18'sh01709; end
            8'd114: begin c = 18'sh3877b; cos_w = 18'sh3c3be; sin_w = 18'sh01590; end
            8'd115: begin c = 18'sh38676; cos_w = 18'sh3c33b; sin_w = 18'sh01413; end
            8'd116: begin c = 18'sh38583; cos_w = 18'sh3c2c1; sin_w = 18'sh01294; end
            8'd117: begin c = 18'sh384a3; cos_w = 18'sh3c251; sin_w = 18'sh01112; end
            8'd118: begin c = 18'sh383d6; cos_w = 18'sh3c1eb; sin_w = 18'sh00f8d; end
            8'd119: begin c = 18'sh3831c; cos_w = 18'sh3c18e; sin_w = 18'sh00e06; end
            8'd120: begin c = 18'sh38276; cos_w = 18'sh3c13b; sin_w = 18'sh00c7c; end
            8'd121: begin c = 18'sh381e2; cos_w = 18'sh3c0f1; sin_w = 18'sh00af1; end
            8'd122: begin c = 18'sh38163; cos_w = 18'sh3c0b1; sin_w = 18'sh00964; end
            8'd123: begin c = 18'sh380f6; cos_w = 18'sh3c07b; sin_w = 18'sh007d6; end
            8'd124: begin c = 18'sh3809e; cos_w = 18'sh3c04f; sin_w = 18'sh00646; end
            8'd125: begin c = 18'sh38059; cos_w = 18'sh3c02c; sin_w = 18'sh004b5; end
            8'd126: begin c = 18'sh38027; cos_w = 18'sh3c014; sin_w = 18'sh00324; end
            8'd127: begin c = 18'sh3800a; cos_w = 18'sh3c005; sin_w = 18'sh00192; end
            default: begin c = 18'sh00000; cos_w = 18'sh00000; sin_w = 18'sh00000; end
        endcase
    end

endmodule

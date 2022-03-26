//
//
// Sam Coupe Video Controller implementation
// 
// Copyright (c) 2016 Sorgelig
//
// 
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or 
// (at your option) any later version. 
// 
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of 
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the 
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License 
// along with this program.  If not, see <http://www.gnu.org/licenses/>. 
//

`timescale 1ns / 1ps

module video
(
	input         reset,

	input         CLK_VIDEO,	// master clock
	output        CE_PIXEL,

	input         ce_6mp,
	input         ce_6mn,
	input         ce_24m,

	// CPU interfacing
	input  [15:0] addr,
	input   [7:0] din,
	output  [7:0] dout,
	output        dout_en,
	input         port_we,

	output        mem_contention,
	output        io_contention,

	output reg    INT_line,
	output reg    INT_frame,

	// VRAM interfacing
	output [18:0] vram_addr1,
	output [18:0] vram_addr2,
	input  [15:0] vram_dout1,
	input  [15:0] vram_dout2,
	output reg    vram_rd,

	// Misc. signals
	input         hq2x,
	input         scandoubler,
	inout  [21:0] gamma_bus,
	input         soff,
	output  [1:0] video_mode,
	input   [1:0] mode3_hi,
	input         midi_tx,
	input         full_zx,
	input         crop,

	// Video outputs
	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_VS,
	output        VGA_HS,
	output        VGA_DE
);

assign io_contention  = |hc[2:0];
assign mem_contention = |{(fetch | (!mode & !full_zx & hc[6])) & hc[2], hc[1:0]};

assign vram_addr1 = vaddr1;
assign vram_addr2 = vaddr2;

reg        HBlank;
reg        HSync;
reg        VBlank;
reg        VSync;

reg  [7:0] attr;
reg [31:0] shift;
reg [18:0] vaddr1;
reg [18:0] vaddr2;

reg  [4:0] flashcnt;
reg        paper, fetch;

reg  [8:0] hc  = 0;
reg  [8:0] vc  = 0;
wire [4:0] col = {~hc[7], hc[6:3]};

reg  [7:0] lpen;
reg  [7:0] hpen;
reg  [3:0] border;

reg mode512;

always @(posedge CLK_VIDEO) begin
	reg m512;
	
	INT_line  <= (hc >= 3) & (hc<132) & (INT_line_no < 192) & (INT_line_no == vc);
	INT_frame <= (hc >= 3) & (hc<132) & (vc == 244);

	if(ce_6mp) begin
		if(~HBlank && ~VBlank) m512 <= (m512 | (mode == 2));
		if (hc==383) begin
			hc <= 0;
			if (vc == 311) begin 
				vc <= 0;
				flashcnt <= flashcnt + 1'd1;
			end else begin
				vc <= vc + 1'd1;
			end
			if( vc == 240) begin
				mode512 <= m512; // | ~hq2x;
				m512 <= 0;
			end
		end else begin
			hc <= hc + 1'd1;
		end
		if(mode == 2) shift <= shift << 2;
	end
	if(ce_6mn) begin
		if(hc == 51)  begin
			HSync  <= 1;
			if( vc == 240) VSync <= 1;
			if( vc == 244) VSync <= 0;
		end
		if(hc == 80)  HSync  <= 0;

		if(crop) begin
			if(hc == 13)  HBlank <= 1;
			if(hc == 131) HBlank <= 0;
		end
		else begin
			if(hc == 44)  HBlank <= 1;
			if(hc == 100) HBlank <= 0;
		end

		if(hc == 100) begin
			if(vc == 226) VBlank <= 1;
			if(vc == 274) VBlank <= 0;
		end

		case(mode)
			0,1: shift <= shift << 1;
			  2: shift <= shift << 2;
			  3: shift <= shift << 4;
		endcase

		if(!hc) fetch <= 0;
		if((hc>=128) & (vc<192) & !hc[2:0]) begin
			fetch <= ~soff;
			if(~soff) begin
				vram_rd <= ~vram_rd;
				case(mode)
					0: {vaddr1,vaddr2} <= { {page, 1'b0, vc[7:6],vc[2:0],vc[5:3],col}, {page, 4'b0110,vc[7:3],col}     };
					1: {vaddr1,vaddr2} <= { {page, 1'b0, vc[7:0],col},                 {page, 1'b1, vc[7:0],col}       };
				 2,3: {vaddr1,vaddr2} <= { {page[4:1],  vc[7:0],col, 2'b00},          {page[4:1],  vc[7:0],col, 2'b10}};
				endcase
			end
		end

		if(!hc[2:0]) begin
			paper <= fetch;
			shift <= {vram_dout1[7:0],vram_dout1[15:8],vram_dout2[7:0],vram_dout2[15:8]};
			attr  <= fetch ? vram_dout2[7:0] : 8'hFF;
			clut  <= clut_raw;
		end

		if(~io_contention) begin
			// due to permanent 1/8 I/O contention only upper 5 bits of counter are meaningful.
			lpen   <= {{5{paper}} & col, 1'b0, midi_tx, index[0]};
			hpen   <= (soff | (vc>192)) ? 8'd192 : vc[7:0];
			border <= border_color;
			m3_idx <= mode3_hi;
		end
	end
end

reg  [1:0] m3_idx;
reg  [3:0] index;

always_comb begin
	casex({paper, mode})
		'b0XX: index = border;
		'b10X: index = (shift[31] ^ (attr[7] & flashcnt[4])) ? {attr[6],attr[2:0]} : {attr[6],attr[5:3]};
		'b110: index = {m3_idx, shift[30], shift[31]};
		'b111: index = shift[31:28];
	endcase
end

wire I;
wire [1:0] R, G, B;
assign {G[1],R[1],B[1],I,G[0],R[0],B[0]} = soff ? 7'b0 : clut[index];

video_mixer #(.LINE_LENGTH(768), .HALF_DEPTH(1), .GAMMA(1)) video_mixer
(
	.*,
	.ce_pix(ce_6mp | (mode512 & ce_6mn)),
	.HDMI_FREEZE(),
	.freeze_sync(),
	.R({R, R[1], I}),
	.G({G, G[1], I}),
	.B({B, B[1], I})
);

//////////////////////////////////////////////////////////////////////////

assign     dout_en = vmpr_sel | attr_sel | lpen_sel | hpen_sel;
assign     dout = port_data;
assign     video_mode = mode;

reg  [7:0] INT_line_no = 255;
reg  [6:0] vmpr;
wire [1:0] mode = vmpr[6:5];
wire [4:0] page = vmpr[4:0];

reg  [7:0] brdr;
wire [3:0] border_color = {brdr[5], brdr[2:0]};

wire       vmpr_sel = (addr[7:0] == 252);
wire       clut_sel = (addr[7:0] == 248);
wire       lpen_sel = (addr[8:0] == 248);
wire       hpen_sel = (addr[8:0] == 504);
wire       intl_sel = (addr[7:0] == 249);
wire       brdr_sel = (addr[7:0] == 254);
wire       attr_sel = (addr[7:0] == 255);

reg  [6:0] clut[16], clut_raw[16];

always @(posedge CLK_VIDEO) begin
	if(reset) vmpr <= 0;
	else begin
		if(port_we) begin
			if(vmpr_sel) vmpr <= din[6:0];
			if(clut_sel) clut_raw[addr[11:8]] <= din[6:0];
			if(intl_sel) INT_line_no <= din;
			if(brdr_sel) brdr <= din;
		end
	end
end

reg [7:0] port_data;
always_comb begin
	casex({vmpr_sel, attr_sel, lpen_sel, hpen_sel})
		'b1XXX: port_data = {1'b1, vmpr};
		'b01XX: port_data = attr;
		'b001X: port_data = lpen;
		'b0001: port_data = hpen;
		'b0000: port_data = 0;
	endcase
end

endmodule

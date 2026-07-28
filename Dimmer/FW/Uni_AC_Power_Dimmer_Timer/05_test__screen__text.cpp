
#include "common.hpp"
#include <string.h>
#include "lcd5x8_font.h"

void set_color(int screen_half, color_t color) {
	switch(screen_half){
		case 0:
			screen.rgb0 = color;
			break;
		case 1:
			screen.rgb1 = color;
			break;
	} 
}

/**
 * 64 cols x 32 rows, 1/8 scan
 * 8 row groups with 8 addrs
 *    addr = 0:
 *    	RGB0:
 *    		rows: 0, 8,
 *    	RGB1:
 *    		rows: 16, 24
 *    addr = 1:
 *    	RGB0:
 *    		rows: 1, 9,
 *    	RGB1:
 *    		rows: 17, 25
 *    		
 * Shift 64 cols x 2 rows
 * 	
 * 	bitplane = 64 cols x 4 rows = 256 LEDs
 */



#define TEXT_ROWS 4
#define TEXT_COLS 10
char text_buf[TEXT_ROWS][TEXT_COLS];

bool bitchase_text(u8 pix_row, u8 pix_col) {
	u8 glyph_col = pix_col % 6;
	if(glyph_col == 5){
		// Empty column.
		return false;
	}
	u8 glyph_row = pix_row % 9;
	if(glyph_row == 8){
		// Empty row.
		return false;
	}
	
	u8 text_col = pix_col / 6;
	if(text_col >= TEXT_COLS) {
		return false;
	}
	
	u8 text_row = pix_row / 9;
	if(text_row >= TEXT_ROWS) {
		return false;
	}
	
	
	char c = text_buf[text_row][text_col];
	if(c < 0x20 || c > 0x7e){
		return false;
	}
	//DEBUG_HEX(c);
	
	u8 glyph_idx = (c - 32) * 5;
	
	u8 line = pgm_read_byte(&lcd5x8_font[glyph_idx + glyph_col]);
	
	return line & (1 << glyph_row);
}

int main(void) {
	screen.odd_0 = wide_bool(DDR_OUT);
	screen.odd_1 = wide_bool(DDR_OUT);
	screen.odd_2 = wide_bool(DDR_OUT);
	screen.odd_3 = wide_bool(DDR_OUT);


	strcpy(&text_buf[0][0], "JEJA");

	//screen.rgb0 = screen.rgb1 = WHITE;
	
	while(1){

		for(int vsync = 0; vsync < 500; vsync++){
			for(int row_grp = 0; row_grp < 8; row_grp++){
				screen.n_oe = 1;
				
				// Set row addr.
				screen.addr = row_grp;

				for(int row_shift = 2; row_shift >= 0; row_shift--){
					for(int col = 0; col < 64; col++){
						for(int screen_half = 0; screen_half < 2; screen_half++){
							int row = screen_half*16 + row_shift*8 + row_grp;
							
							bool pix = true;
							pix = bitchase_text(row, col);
							set_color(screen_half, pix ? RED : BLACK);
						}
						
						// Bit pulse.
						screen.clk = 1;
						screen.clk = 0;
					} 
					
				}

				// Latch pulse.
				screen.latch = 1;
				//_delay_us(1); // For scope
				screen.latch = 0;

				// Turn on LEDs.
				screen.n_oe = 0;

				_delay_us(100);
			}
		}

	} // while

}
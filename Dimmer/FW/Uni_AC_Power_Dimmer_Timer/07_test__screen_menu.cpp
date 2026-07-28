
#include "common.hpp"
#include <string.h>
#include "lcd5x8_font.h"
#include "uart_stdio.hpp"


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

// SCREEN X KEYBOARD

enum ScreenState {
    MENU,
    SETTINGS,
    INFO
};

ScreenState current_screen = MENU;


char keymap[5][4] = {
	{'X','Y','#','*'}, // R0 (TOP ROW)
	{'1','2','3','U'}, // R1	
	{'4','5','6','D'}, // R2
	{'7','8','9','Q'}, // R3
    {'L','0','R','E'}   // R4 (BOTTOM ROW)
};

char last_key = 0;

char scan_keyboard() {

    for (int row = 0; row < 5; row++) {

        keyboard.rows_out = 0b1111;
		keyboard.r0_out = 1;
		
        // drive one row LOW
        switch (row) {
            case 0: keyboard.r0_out = 0; break;
            case 1: keyboard.r1_out = 0; break;
            case 2: keyboard.r2_out = 0; break;
            case 3: keyboard.r3_out = 0; break;
            case 4: keyboard.r4_out = 0; break;
        }

        _delay_us(5);

        // --- read columns (PC4–PC7) ---
        if (!keyboard.c0) return keymap[row][0]; // C0
        if (!keyboard.c1) return keymap[row][1]; // C1
        if (!keyboard.c2) return keymap[row][2]; // C2
        if (!keyboard.c3) return keymap[row][3]; // C3
    }

    return 0;
}

void handle_key(char key) {
    if (!key) return;

    switch(current_screen) {

        case MENU:
            if(key == '1') current_screen = SETTINGS;
            if(key == '2') current_screen = INFO;
            break;

        case SETTINGS:
            if(key == 'Q') current_screen = MENU;
            break;

        case INFO:
            if(key == 'Q') current_screen = MENU;
            break;
    }
}


void render_screen() {

    // clear buffer
    for(int r = 0; r < TEXT_ROWS; r++)
        for(int c = 0; c < TEXT_COLS; c++)
            text_buf[r][c] = ' ';

    switch(current_screen) {

	// --- KEYBOARD INIT ---

	// --- KEYBOARD INIT (FLIPPED) ---
        case MENU:
            strcpy(text_buf[0], "1 SETTINGS");
            strcpy(text_buf[1], "2 INFO");
            break;

        case SETTINGS:
            strcpy(text_buf[0], "SETTINGS");
            strcpy(text_buf[1], "ESC BACK");
            break;

        case INFO:
            strcpy(text_buf[0], "INFO PAGE");
            strcpy(text_buf[1], "ESC BACK");
            break;
    }
}


int main(void) {
	screen.odd_0 = wide_bool(DDR_OUT);
	screen.odd_1 = wide_bool(DDR_OUT);
	screen.odd_2 = wide_bool(DDR_OUT);
	screen.odd_3 = wide_bool(DDR_OUT);

	uart_stdio_non_blocking<100> _u;
	printf("Hello!\n\r");
	printf("Hello again!\n\r");
	printf("F_CPU = %ld\n\r", F_CPU);

	// --- KEYBOARD INIT ---

	// rows = outputs
	keyboard.r0_dir = 1;
	keyboard.r1_dir = 1;
	keyboard.r2_dir = 1;
	keyboard.r3_dir = 1;
	keyboard.r4_dir = 1;

	// columns = inputs
	keyboard.c0_dir = 0;
	keyboard.c1_dir = 0;
	keyboard.c2_dir = 0;
	keyboard.c3_dir = 0;

	// enable pullups on columns
	keyboard.cols_pullup = 0b1111;

	// inactive rows HIGH
	keyboard.r0_out = 1;
	keyboard.rows_out = 0b1111; 	// R1 - R4

	//screen.rgb0 = screen.rgb1 = WHITE;
	
	while(1){
			// --- INPUT ---
		char key = scan_keyboard();
		printf("Key: %c\n\r", key);

		// simple debounce (important)
		if(key && key != last_key){
			handle_key(key);
			last_key = key;
		}
		if(!key) last_key = 0;

		// --- LOGIC → RENDER ---
		render_screen();

		for(int vsync = 0; vsync < 20; vsync++){
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

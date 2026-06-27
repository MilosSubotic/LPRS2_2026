#include "common.hpp"
#include <string.h>
#include <stdlib.h>

#include "lcd5x8_font.h"
#include "uart_stdio.hpp"

#include "dimmer.hpp"
#include "dimmer.cpp"

void set_color(int screen_half, color_t color)
{
    switch(screen_half)
    {
        case 0:
            screen.rgb0 = color;
            break;

        case 1:
            screen.rgb1 = color;
            break;
    }
}

#define TEXT_ROWS 4
#define TEXT_COLS 10

char text_buf[TEXT_ROWS][TEXT_COLS];

bool bitchase_text(u8 pix_row, u8 pix_col)
{
    u8 glyph_col = pix_col % 6;

    if(glyph_col == 5)
        return false;

    u8 glyph_row = pix_row % 9;

    if(glyph_row == 8)
        return false;

    u8 text_col = pix_col / 6;

    if(text_col >= TEXT_COLS)
        return false;

    u8 text_row = pix_row / 9;

    if(text_row >= TEXT_ROWS)
        return false;

    char c = text_buf[text_row][text_col];

    if(c < 0x20 || c > 0x7e)
        return false;

    u8 glyph_idx = (c - 32) * 5;

    u8 line = pgm_read_byte(&lcd5x8_font[glyph_idx + glyph_col]);

    return line & (1 << glyph_row);
}

/*****************************************************************/
/* SCREEN STATE                                                  */
/*****************************************************************/

enum ScreenState
{
    MENU,
    DIMMER,
    INFO
};

ScreenState current_screen = MENU;

/*****************************************************************/
/* KEYBOARD                                                      */
/*****************************************************************/

char keymap[5][4] = {
    {'X','Y','#','*'},
    {'1','2','3','U'},
    {'4','5','6','D'},
    {'7','8','9','Q'},
    {'L','0','R','E'}
};

char last_key = 0;

char percent_buf[4] = "";
uint8_t percent_len = 0;

bool first_digit = true;

char scan_keyboard()
{
    for(int row = 0; row < 5; row++)
    {
        keyboard.rows_out = 0b1111;
        keyboard.r0_out = 1;

        switch(row)
        {
            case 0: keyboard.r0_out = 0; break;
            case 1: keyboard.r1_out = 0; break;
            case 2: keyboard.r2_out = 0; break;
            case 3: keyboard.r3_out = 0; break;
            case 4: keyboard.r4_out = 0; break;
        }

        _delay_us(5);

        if(!keyboard.c0) return keymap[row][0];
        if(!keyboard.c1) return keymap[row][1];
        if(!keyboard.c2) return keymap[row][2];
        if(!keyboard.c3) return keymap[row][3];
    }

    return 0;
}

/*****************************************************************/
/* INPUT HANDLER                                                 */
/*****************************************************************/

void handle_key(char key)
{
    if(!key) return;

    switch(current_screen)
    {
        case MENU:

           if(key == 'X')   //F1
            {
                current_screen = DIMMER;

                sprintf(percent_buf, "%d", dimmer_get_percent());

                percent_len = strlen(percent_buf);

                first_digit = true;
            }

            if(key == 'Y')  //F2
            {
                current_screen = INFO;
            }

            break;

        case DIMMER:

            if(key >= '0' && key <= '9')
            {
                if(first_digit)
                {
                    percent_len = 0;
                    percent_buf[0] = '\0';
                    first_digit = false;
                }


                if(percent_len < 3)
                {
                    percent_buf[percent_len++] = key;
                    percent_buf[percent_len] = '\0';
                }
            }

            if(key == 'L')  // Backspace
            {
                if(percent_len > 0)
                {
                    percent_len--;
                    percent_buf[percent_len] = '\0';
                }
            }

            if(key == 'E')  // Enter
            {
                int p = atoi(percent_buf);

                if(p >= 0 && p <= 100)
                {
                    dimmer_set_percent(p);

                    current_screen = MENU;
                }
            }

            if(key == 'Q')  // Esc
            {
                current_screen = MENU;
            }

            break;

        case INFO:

            if(key == 'Q')  // Esc
            {
                current_screen = MENU;
            }

            break;
    }
}

/*****************************************************************/
/* SCREEN RENDER                                                 */
/*****************************************************************/

void render_screen()
{
    for(int r = 0; r < TEXT_ROWS; r++)
    {
        for(int c = 0; c < TEXT_COLS; c++)
        {
            text_buf[r][c] = ' ';
        }
    }

    switch(current_screen)
    {
        case MENU:

            sprintf(text_buf[0], "DIM=%d%%", dimmer_get_percent());

            strcpy(text_buf[1], "F1 EDIT");
            strcpy(text_buf[2], "F2 INFO");

            break;

        case DIMMER:

            strcpy(text_buf[0], "DIMMER");

            if(percent_len == 0)
                strcpy(text_buf[1], "0%");
            else
                sprintf(text_buf[1], "%s%%", percent_buf);

            strcpy(text_buf[2], "ENTER SET");
            strcpy(text_buf[3], "ESC EXIT");

            break;

        case INFO:

            strcpy(text_buf[0], "PHASE");
            strcpy(text_buf[1], "ANGLE");
            strcpy(text_buf[2], "DIMMER");
            strcpy(text_buf[3], "ESC EXIT");

            break;
    }
}

/*****************************************************************/
/* MAIN                                                          */
/*****************************************************************/

int main(void)
{
    screen.odd_0 = wide_bool(DDR_OUT);
    screen.odd_1 = wide_bool(DDR_OUT);
    screen.odd_2 = wide_bool(DDR_OUT);
    screen.odd_3 = wide_bool(DDR_OUT);

    uart_stdio_non_blocking<100> _u;

    printf("Dimmer Menu\n\r");

    keyboard.r0_dir = 1;
    keyboard.r1_dir = 1;
    keyboard.r2_dir = 1;
    keyboard.r3_dir = 1;
    keyboard.r4_dir = 1;

    keyboard.c0_dir = 0;
    keyboard.c1_dir = 0;
    keyboard.c2_dir = 0;
    keyboard.c3_dir = 0;

    keyboard.cols_pullup = 0b1111;

    keyboard.r0_out = 1;
    keyboard.rows_out = 0b1111;

    dimmer_init();

    while(1)
    {
        char key = scan_keyboard();

        if(key && key != last_key)
        {
            handle_key(key);
            last_key = key;
        }

        if(!key)
        {
            last_key = 0;
        }

        render_screen();

        for(int vsync = 0; vsync < 50; vsync++)
        {
            for(int row_grp = 0; row_grp < 8; row_grp++)
            {
                screen.n_oe = 1;

                screen.addr = row_grp;

                for(int row_shift = 2; row_shift >= 0; row_shift--)
                {
                    for(int col = 0; col < 64; col++)
                    {
                        for(int screen_half = 0; screen_half < 2; screen_half++)
                        {
                            int row =
                                screen_half * 16 +
                                row_shift * 8 +
                                row_grp;

                            bool pix =
                                bitchase_text(row, col);

                            set_color(
                                screen_half,
                                pix ? RED : BLACK
                            );
                        }

                        screen.clk = 1;
                        screen.clk = 0;
                    }
                }

                screen.latch = 1;
                screen.latch = 0;

                screen.n_oe = 0;

                _delay_us(100);
            }
        }
    }
}
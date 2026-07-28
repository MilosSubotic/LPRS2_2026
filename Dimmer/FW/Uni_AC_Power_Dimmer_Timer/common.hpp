
#pragma once


#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdlib.h>
#include <stdio.h>

#include "avr_io_bitfields.h"
#include "uart_stdio.hpp"


struct bf_screen {
	// PIND
	u8        : 8;
	// DDRD
	u8        : 8;
	// PORTD
	u8        : 8;

	// PINC
	u8        : 8;

	// DDRC
	u8 odd_0  : 3;
	u8        : 5;

	// PORTC
	union {
		u8 addr   : 3;
		struct {
			u8 a  : 1;
			u8 b  : 1;
			u8 c  : 1;
			u8    : 5;
		};
	};

	// PINB
	u8        : 8;

	// DDRB
	u8        : 3;
	u8 odd_1  : 2;
	u8        : 1;
	u8 odd_2  : 1;
	u8        : 1;

	// PORTB
	u8        : 3;
	u8 n_oe   : 1;
	u8 clk    : 1;
	u8        : 1;
	u8 latch  : 1;
	u8        : 1;

	// PINA
	u8        : 8;

	// DDRA
	u8 odd_3  : 6;
	u8        : 2;

	// PORTA
	union {
		struct {
			u8 r0 : 1;
			u8 g0 : 1;
			u8 b0 : 1;
			u8 r1 : 1;
			u8 g1 : 1;
			u8 b1 : 1;
			u8    : 2;
		};
		struct {
			u8 rgb0 : 3;
			u8 rgb1 : 3;
			u8      : 2;
		};
	};
};
#define screen (*((volatile bf_screen*)(&PIND)))


enum color_t {
	BLACK,
	RED,
	GREEN,
	YELLOW,
	BLUE,
	MAGENTA,
	CYAN,
	WHITE
};



struct bf_zero_cross_triac {
	// PIND
	u8        : 2;
	u8 zc1    : 1;
	u8 zc2    : 1;
	u8        : 4;
	// DDRD
	u8        : 2;
	u8 idd_0  : 2;
	u8 odd_0  : 2;
	u8        : 1;
	u8 odd_1  : 1;

	// PORTD
	u8        : 4;
	u8 drv1   : 1;
	u8 drv2   : 1;
	u8        : 1;
	u8 drv3   : 1;

	// PINC
	u8        : 8;
	// DDRC
	u8        : 8;
	// PORTC
	u8        : 8;

	// PINB
	u8        : 2;
	u8 zc3    : 1;
	u8        : 5;
	// DDRB
	u8        : 2;
	u8 idd_1  : 1;
	u8        : 5;
	// PORTB
	u8        : 8;

	// PINA
	u8        : 8;
	// DDRA
	u8        : 8;
	// PORTA
	u8        : 8;
};
#define zct (*((volatile bf_zero_cross_triac*)(&PIND)))

struct bf_keyboard {
	// PIND
	u8        : 6;
	u8 r0     : 1;
	u8        : 1;

	// DDRD
	u8        : 6;
	u8 r0_dir : 1;
	u8        : 1;

	// PORTD
	u8        : 6;
	u8 r0_out : 1;
	u8        : 1;


	// PINC
	union {
		struct {
			u8 r1 : 1;
			u8 r2 : 1;
			u8 r3 : 1;
			u8 r4 : 1;

			u8 c3 : 1;
			u8 c2 : 1;
			u8 c1 : 1;
			u8 c0 : 1;
		};

		struct {
			u8 rows_in : 4;
			u8 cols_in : 4;
		};
	};

	// DDRC
	union {
		struct {
			u8 r1_dir : 1;
			u8 r2_dir : 1;
			u8 r3_dir : 1;
			u8 r4_dir : 1;

			u8 c3_dir : 1;
			u8 c2_dir : 1;
			u8 c1_dir : 1;
			u8 c0_dir : 1;
		};
	};

	// PORTC
	union {
		struct {
			u8 r1_out : 1;
			u8 r2_out : 1;
			u8 r3_out : 1;
			u8 r4_out : 1;

			u8 c3_pullup : 1;
			u8 c2_pullup : 1;
			u8 c1_pullup : 1;
			u8 c0_pullup : 1;
		};

		struct {
			u8 rows_out : 4;
			u8 cols_pullup : 4;
		};
	};


	// PINB
	u8        : 8;

	// DDRB
	u8        : 8;

	// PORTB
	u8        : 8;

	// PINA
	u8        : 8;

	// DDRA
	u8        : 8;

	// PORTA
	u8        : 8;
};

#define keyboard (*((volatile bf_keyboard*)(&PIND)))

// Test with:
// ./waf debug_uart --port=0

#include "common.hpp"

#include "uart_stdio.hpp"

int main(void) {
	screen.odd_0 = wide_bool(DDR_OUT);
	screen.odd_1 = wide_bool(DDR_OUT);
	screen.odd_2 = wide_bool(DDR_OUT);
	screen.odd_3 = wide_bool(DDR_OUT);

	//screen.rgb0 = screen.rgb1 = WHITE;

	ddrc.b0 = 0;	//DDR_IN
	ddrc.b1 = 0;
	ddrc.b2 = 0;
	ddrc.b3 = 0;	
	ddrc.b4 = 1;	//DDR_OUT
	ddrc.b5 = 1;
	ddrc.b6 = 1;
	ddrc.b7 = 1;

	// pull-ups on rows
	portc.b0 = 1;
	portc.b1 = 1;
	portc.b2 = 1;
	portc.b3 = 1;

	// columns HIGH
	portc.b4 = 1;
	portc.b5 = 1;
	portc.b6 = 1;
	portc.b7 = 1;

	ddrd.b6 = 0;
	portd.b6 = 1;	//PORT_IN_PULL_UP

	uart_stdio_non_blocking<100> _u;
	printf("Hello!\n\r");
	printf("Hello again!\n\r");
	printf("F_CPU = %ld\n\r", F_CPU);
	
	while(1){

		printf("PC: %02X PD: %02X\n\r", PINC, PIND);
		_delay_ms(200);

		for (int col = 0; col < 4; col++) {

			// all columns HIGH
			portc.b4 = 1;
			portc.b5 = 1;
			portc.b6 = 1;
			portc.b7 = 1;

			// set one column LOW
			switch (col) {
				case 0: portc.b7 = 0; break; // C0
				case 1: portc.b6 = 0; break; // C1
				case 2: portc.b5 = 0; break; // C2
				case 3: portc.b4 = 0; break; // C3
			}

			_delay_us(5);

			// R0 (PD6)
			if (!pind.b6) {
				printf("R0 C%d\n\r", col);
			}

			// R1–R4 (PC0–PC3)
			if (!pinc.b0) printf("R1 C%d\n\r", col);
			if (!pinc.b1) printf("R2 C%d\n\r", col);
			if (!pinc.b2) printf("R3 C%d\n\r", col);
			if (!pinc.b3) printf("R4 C%d\n\r", col);
		}

	} // while

}


// Test with:
// ./waf debug_log --port=0

#include "dimmer.hpp"

#define HZ 50

//////////////

#define PRESCALE 8
#define PRESCALE_CODE 0b010

//////////////
// Calculated

#define TOP (F_CPU/((HZ)*2*8))

volatile u8 dimmer_percent = 100;

volatile uint16_t threshold_a;
volatile uint16_t threshold_b;

//////////////

u8 second_half_period;

void dimmer_set_percent(u8 percent) {
    if(percent > 100) percent = 100;

    dimmer_percent = percent;
    
    threshold_a = TOP*(100-percent)/100;
    threshold_b = threshold_a+10;
}

u8 dimmer_get_percent() {
    return dimmer_percent;
}


// Zero-cross start of period.
ISR(INT2_vect) {
	portc.b7 = !portc.b7;

	// Reset counter.
	second_half_period = 0;

	// Set trigger moment.
	tc1.ocra = threshold_a;
	tc1.ocrb = threshold_b;

	// Turn on IRQs.
	irq.ocie1a = irq.ocie1b = 1;

	// Reset counter
	tc1.tcnt = 0;
}

// Start of triac pulse.
ISR(TIMER1_COMPA_vect) {
	zct.drv3 = 1;
	portc.b6 = 1; // Mirror DRV3 for debug.
}

// End of triac pulse.
ISR(TIMER1_COMPB_vect) {
	zct.drv3 = 0;
	portc.b6 = 0; // Mirror DRV3 for debug.
}


// End of half-period.
ISR(TIMER1_CAPT_vect) {
	if(second_half_period){
		// Turn off IRQs after 2nd half-period,
		// so if there is not zero-cross
		// triac would not be triggered.
		irq.ocie1a = irq.ocie1b = 1;
	}
	second_half_period = true;
}


void dimmer_init() {

    ddrc.b4 = DDR_OUT;
    ddrc.b5 = DDR_OUT;
    ddrc.b6 = DDR_OUT;
    ddrc.b7 = DDR_OUT;

    zct.odd_1 = DDR_OUT;
    zct.drv3 = 0;

    zct.idd_1 = DDR_IN;

    irq.int2 = 1;
    irq.isc2 = 0;

    irq.ticie1 = 1;

    irq.ocie1a = 0;
    irq.ocie1b = 0;

    tc1.tccra = 0;
    tc1.tccrb = 0;

    tc1.cs = PRESCALE_CODE;

    tc1.ocra = 0;
    tc1.ocrb = 0;

    tc1.icr = TOP;

    tc1.wgm3 = 1;
    tc1.wgm2 = 1;
    tc1.wgm1 = 0;
    tc1.wgm0 = 0;

    dimmer_set_percent(100);

    sei();
}

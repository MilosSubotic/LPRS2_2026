#!/usr/bin/env julia

include("../Portal_inc.jl")


portal = Portal_Wormhole(BACKEND_USB, PG_ADC_PMOD_POLL)
adc = ADC_Pmod_Poll(portal)

try
	@show read_word(adc, adc_poll_cfg.RM_magic)
	#@show adc_poll_cfg.MAGIC
	@assert read_word(adc, adc_poll_cfg.RM_magic) == adc_poll_cfg.MAGIC

	@show read_word(adc, adc_poll_cfg.RM_version)
	#@show adc_poll_cfg.VERSION
	@assert (read_word(adc, adc_poll_cfg.RM_version) >> 16 & 0xff) == adc_poll_cfg.VERSION_MAJOR

	@assert (read_word(adc, adc_poll_cfg.RM_version) >> 0 & 0xff) == adc_poll_cfg.VERSION_MINOR

	for i=1:10 
		#TODO Poll adc reg
		@show Int(poll(adc))
	end


finally
	close(portal)
end

println("End")

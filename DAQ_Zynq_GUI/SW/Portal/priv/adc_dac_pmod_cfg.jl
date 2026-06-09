module adc_dac_pmod_cfg

	const MAGIC = 0x00adcdac
	const VERSION_MAJOR = 1
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 1
	const VERSION_DESCRIPTION = "Version with one dac_jmp and adc_lvds"
	# Use DAC_JMP instead one DAC_PMOD
	const USE_DAC_JMP = 0x00000001
	# Use ADC_LVDS instead one ADC_PMOD
	const USE_ADC_LVDS = 0x00000001

end # module

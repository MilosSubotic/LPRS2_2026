module dac_jmp_cfg

	const MAGIC = 0x00ad5541
	const VERSION_MAJOR = 0
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 2
	const VERSION_DESCRIPTION = "Pump, probe."
	const F_AXI = 50000000
	# TODO use it
	const F_CNV = 10000000
	const F_SCK = 5000000
	const N_CH = 1

	const RM_magic = 0
	const RM_version = 1
	const RM_f_axi = 2
	const RM_f_cnv = 3
	const RM_pump_mod = 4
	const RM_pump_th = 5
	const RM_jmp_mod = 6
	const RM_jmp_th = 7
	const RM_V_pump1 = 8
	const RM_V_pump2 = 9
	const RM_V_probe = 10
	const RM_strobe = 11
	const RM_probe = 12

end # module

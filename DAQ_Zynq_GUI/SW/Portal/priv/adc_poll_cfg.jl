module adc_poll_cfg

	const MAGIC = 0x0ad7476a
	const VERSION_MAJOR = 0
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 1
	const VERSION_DESCRIPTION = "Initial version"
	const F_AXI = 50000000
	# TODO use it
	const F_CNV = 10000000
	const F_SCK = 5000000
	const N_CH = 1

	const RM_magic = 0
	const RM_version = 1
	const RM_f_axi = 2
	const RM_f_cnv = 3
	const RM_smpl = 4

end # module

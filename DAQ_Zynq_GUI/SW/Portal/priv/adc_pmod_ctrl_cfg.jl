module adc_pmod_ctrl_cfg

	const MAGIC = 0x0ad7476a
	const VERSION_MAJOR = 1
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 12
	const VERSION_DESCRIPTION = "RTL restored to previous working commit"
	const F_AXI = 50000000
	# TODO use it
	const F_CNV = 10000000
	const F_SCK = 5000000
	const CNV_TRIG_SIZE_ADDR = 0x00000000
	# [%]
	const CNV_PROGRESS_ADDR = 0x00000004
	const POLL_SMPLS_ADDR = 0x00000008
	const CH_ENABLE_ADDR = 0x00000010
	# 64MiB
	const BUF_ADDR = 0x04000000
	# 64MiB
	const BUF_SIZE = 0x04000000
	# 64MiB
	const BUF1_ADDR = 0x08000000
	# 64MiB
	const BUF1_SIZE = 0x04000000
	const N_CH = 2

	const RM_magic = 0
	const RM_version = 1
	const RM_f_axi = 2
	const RM_f_cnv = 3
	const RM_ch_enable  = 4
	const RM_smpl_0 = 5
	const RM_smpl_1 = 6
	const RM_pkg_size_words = 7
	const RM_pkg_cnt_0 = 8
	const RM_pkg_cnt_1 = 9
	const RM_drops = 10
	const RM_errors = 11

end # module

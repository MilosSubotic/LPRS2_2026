module adc_lvds_cfg

	const MAGIC = 0x10ad7960
	const VERSION_MAJOR = 1
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 2
	const VERSION_DESCRIPTION = "Just 1 ch"
	const F_AXI = 50000000
	const F_ADC_SER = 200000000
	const F_CNV = 5000000
	const N_CH = 1
	# 0 - daughter, from ADC board, through clk buf
	# 1 - internal, from AXI clk
	# 2 - backdoor, from PMOD|FireFly connector, through FPGA
	# 3 - backdoor, but single ended
	const CNV_SRC = 1
	const CNV_TRIG_SIZE_ADDR = 0x00000000
	# [%]
	const CNV_PROGRESS_ADDR = 0x00000004
	# 64MiB
	const BUF_ADDR = 0x04000000
	# 64MiB
	const BUF_SIZE = 0x04000000

	const RM_magic = 0
	const RM_version = 1
	const RM_f_axi = 2
	const RM_f_adc_ser = 3
	const RM_f_cnv = 4
	const RM_pkg_size_words = 5
	const RM_en = 6
	const RM_pkg_cnt = 7
	const RM_drops = 8
	const RM_errors = 9
	const RM_adc_en_cfg_vec = 10
	const RM_ch_en = 11

end # module

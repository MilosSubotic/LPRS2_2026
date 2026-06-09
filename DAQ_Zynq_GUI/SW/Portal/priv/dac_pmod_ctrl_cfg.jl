module dac_pmod_ctrl_cfg

	const MAGIC = 0x00ad5541
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
	const CNV_TRIG_SIZE_ADDR = 0x00000000
	# [%]
	const CNV_PROGRESS_ADDR = 0x00000004
	const POLL_SMPL_ADDR = 0x00000008
	const CPU_DONE_ADDR = 0x0000000c
	const DMA_DONE_ADDR = 0x00000010
	const STOP_ADDR = 0x00000014
	# 64MiB
	const BUF_ADDR = 0x04000000
	# 64MiB
	const BUF_SIZE = 0x04000000

	const RM_magic = 0
	const RM_version = 1
	const RM_f_axi = 2
	const RM_f_cnv = 3
	const RM_smpl = 4

end # module

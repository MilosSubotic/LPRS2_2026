module sv_cpu_cfg

	const MAGIC = 0xdeadbeefbabadeda
	const VERSION_MAJOR = 0
	# Change everytime HDL is changed
	# To check in SW that system.bit is updated as should be.
	const VERSION_MINOR = 32
	const VERSION_DESCRIPTION = "perf_cnt, dac_jmp continuous."
	# Addr bits in B
	const WORD_AW = 3
	# Addr bits in words
	const CTRL_AW = 16
	const REG_UA = 0x00000000
	const REG_CW = 13
	const REG_AW = 4
	const INSTR_UA = 0x00000001
	const INSTR_CW = 13
	# 1k BRAM
	const INSTR_AW = 10
	const SDATA_UA = 0x00000002
	const SDATA_CW = 13
	const SDATA_AW = 13
	const VDATA_UA = 0x00000001
	const VDATA_CW = 15
	# 2 lanes 4k URAM
	const VDATA_AW = 13
	# 100MHz - Should pass timing and useful for ALU.
	# # 200MHz - For simulation.
	# # 187.5MHz - From dual_port_single_clk_ram tuning. Does not pass timing with ALU.
	# # 145MHz - Pass timing in ALU?
	# 
	const F_ALU = 100000000
	const EN_s_f64 = true
	const LANES_LOG2 = 5
	const MAX_WAVES_LOG2 = 4

	const RM_magic = 0
	const RM_version = 1
	const RM_n_sw_rst = 2
	const RM_pause = 3
	const RM_pc = 4
	const RM_exc = 5
	const RM_err_non_word_we = 6
	const RM_perf_cnt = 7

end # module

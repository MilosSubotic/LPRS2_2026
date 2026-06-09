#!/usr/bin/env julia

include("../Portal_inc.jl")


portal = Portal_Wormhole(BACKEND_USB, PG_DAC_JMP)
dac = DAC_Jmp(portal)

try
	@show read_word(dac, dac_jmp_cfg.RM_magic)
	@show read_word(dac, dac_jmp_cfg.RM_version)

	function mon_probe()
		# Wait FE
		while probe(dac)
		end

		# Wait RE
		while !probe(dac)
		end
		t_probe_start = time()
		#@show probe(dac)

		# Wait FE
		while probe(dac)
		end
		t_probe_end = time()
		#@show probe(dac)

		t_probe_ms = (t_probe_end - t_probe_start)*1e3

		@show t_probe_ms
	end

	mon_probe()

	set_cfg!(
		dac,
		t_pump = 10m,
		t_probe = 20m,
		f_2larmor = 10k,
		V_pump1 = 0.5,
		V_pump2 = 1.5,
		V_probe = 1.0,
	)

	mon_probe()


finally
	close(portal)
end

println("End")

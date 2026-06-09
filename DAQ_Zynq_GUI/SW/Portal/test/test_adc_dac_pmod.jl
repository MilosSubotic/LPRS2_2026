#!/usr/bin/env julia

include("../Portal_inc.jl")


portal = Portal_Wormhole(BACKEND_USB, PG_ADC_DAC_PMOD)
adc0 = ADC_PMOD_CTRL(portal)
adc1 = ADC_PMOD_CTRL(portal)
#dac0 = DAC_Jmp(portal)
#dac1 = DAC_Jmp(portal)

function test_adc(adc::ADC_PMOD_CTRL, N::Int)
	#N = 64 # 1 iter, 1 chunk
		#N = 128 # 1 iter, 2 chunks
		#N = 256 # 2 iters, 4 chunks
		#N = Int(5e6) # 1 sec
		
		cnv_trig(adc, N)

		while true
			sleep(0.1)
			progress = cnv_progress(adc)
			println("Progress $progress%")
			if progress == 100
				break
			end
		end

		samples = zeros(UInt32, N)
		read_buf!(adc, samples)

		@show Int(UInt32(poll(adc)))
		for i in 1:8:256
			@show Int.(samples[i:i+7])
		end

		#@show samples[64]
		#@show samples[65]
		#@show samples[128]
end

function test_dac(dac::DAC_Jmp)

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

end

try
	N = 256
	if false
		println("Testing ADC_PMOD_CTRL and DAC_JMP together")
	elseif false
		test_adc(adc1, N)
		test_dac(dac1)
	else
		test_adc(adc0, N)
		test_dac(dac0)
	end
catch e
	println("Error: $e")
finally
	close(portal)
end

println("End")

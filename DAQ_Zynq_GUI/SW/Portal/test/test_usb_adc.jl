#!/usr/bin/env julia

include("../Portal_inc.jl")


portal = Portal_Wormhole(BACKEND_USB, PG_ADC_DMA)
adc = ADC_DMA(portal)

try
	if false
		N = 256
		#N = 1
		data = zeros(UInt8, N)
		for i in 1:length(data)
			data[i] = (i-1) & 0xff
		end
		write(adc, UInt32(0), data)

		for i in 1:length(data)
			data[i] = 0
		end

		read!(adc, UInt32(0), data)

		@show data[1:min(10, end)]
	elseif false
		samples = zeros(UInt32, 64)
		samples[1] = 0xbabadeda

		write_buf(adc, samples)

		read_buf!(adc, samples)

		@show samples[1:4]
	else
		#N = 64 # 1 iter, 1 chunk
		N = 128 # 1 iter, 2 chunks
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

		@show samples[1:4]
		#@show samples
		@show samples[64]
		@show samples[65]
		@show samples[128]


	end

finally
	close(portal)
end

println("End")

#!/usr/bin/env julia

include("../Portal_inc.jl")


f_smpl = 5M
ms_to_smpl(ms) = round(Int, ms/1000*f_smpl)

N_smpls = Int(5M)


#plot_between = 1:Int(0.5M) # Around of 1 period.
#plot_between = ms_to_smpl(38):ms_to_smpl(73) # Probing signal
plot_between = ms_to_smpl(1):ms_to_smpl(2) # Probing signal


portal = Portal_Worm(BACKEND_USB)
adc = ADC_DMA(portal)

try
	cnv_trig(adc, N_smpls)

	while true
		sleep(0.1)
		progress = cnv_progress(adc)
		println("Progress $progress%")
		if progress == 100
			break
		end
	end

	global tag_samples
	tag_samples = zeros(UInt32, N_smpls)
	read_buf!(adc, tag_samples)


finally
	close(portal)
end

bits = 18
min_max = (
	-(1 << (bits-1)),
	(1 << (bits-1)) - 1,
)

samples = Int32[
	reinterpret(Int32, ts << (32-bits)) >> (32-bits) for ts in tag_samples
]

T = 1/f_smpl
t = collect(0:length(samples)-1) .* T

scale = 5/(1 << bits)
V = samples.*scale

@show minimum(V)
@show maximum(V)

if false
	using DelimitedFiles
	writedlm("V.tsv", V, '\t')
end


using Plots
#pyplot(size = (1600, 800))
pyplot()


closeall()
default(reuse = false)


pl = plot(
	title = "ADC samples",
	xlabel = "Time [ms]",
	ylabel = "Signal [mV]",
)

t_ms = 1e3*t[plot_between]
plot!(
	pl,
	t_ms,
	1e3*V[plot_between],
	label = "mV"
)
gui(pl)

println("End")


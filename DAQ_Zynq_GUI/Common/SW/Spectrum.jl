
module Spectrum
	export
		spectrum,
		spectrum_freq,
		dft,
		dft_spectrum,
		dft_spectrum_freq

	import Utils: install_if_not_installed
	install_if_not_installed(["FFTW"])
	using FFTW

	function spectrum(x)
		fx = FFTW.fft(x)
		N_2 = length(x) >> 1
		hfx = fx[1:N_2]
		ha = abs.(hfx)
		sha = (1.0/N_2) * ha
		return sha
	end


	function spectrum_freq(N_smpls, f_smpl)
		f = FFTW.fftfreq(N_smpls, f_smpl)
		N_2 = length(f) >> 1
		hf = f[1:N_2]
		return hf
	end


	function dft(
		x::AbstractArray{T},
		F::AbstractArray{T} = LinRange(0, 0.5, 64)
	) where {
		T <: Number
	}
		@assert all(0 .<= F .<= 0.5)
		kernel = ℯ.^(-im*T(2π)*F)

		dft = zeros(Complex{T}, length(F))

		#@inbounds for xi in 1:length(x)
		#	dft += kernel.^xi * x[xi]
		#end
		# Faster metod.
		kernel_acc = ones(Complex{T}, length(F))
		@inbounds for xi in 1:length(x)
			kernel_acc .*= kernel
			dft .+= kernel_acc .* x[xi]
		end

		return dft
	end

	function dft_spectrum(x, F)
		dft_x = dft(x, F)
		a = abs.(dft_x)
		return a
	end
	
	function dft_spectrum_freq(
		N_samples,
		f_sample;
		f_min = 0,
		f_max = 0.5*f_sample
	)
		dft_f = collect(LinRange(f_min, f_max, N_samples))
		dft_F = dft_f./f_sample
		return dft_f, dft_F
	end

end
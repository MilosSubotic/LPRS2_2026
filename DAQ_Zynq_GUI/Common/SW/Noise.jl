
module Noise

	export white_noise


	import Utils: install_if_not_installed 
	install_if_not_installed(["Distributions"])

	import Random
	import Distributions: Normal, rand

	# To have repeatable noise.
	Random.seed!(1)

	@doc """
	parameters: 
	ρ - spectral noise density unit/SQRT(Hz)
	f_smpl  - sample rate
	N   - no of points
	μ  - mean value, optional

	returns:
	n points of noise with spectral noise density of rho
	"""
	function white_noise(ρ, f_smpl, N, μ = 0)
		# -T Understand this
		#	<-- PSD
		σ = ρ * sqrt(f_smpl/2)
		d = Normal(μ, σ)
		noise = rand(d, N)
		return noise
	end

end
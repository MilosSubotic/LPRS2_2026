
module Electronics_Helpers
	export
		E_series,
		R,
		is_leaf,
		show, +, -, *, |, /, ==, <, hash,
		find_ser_comb,
		find_comb,
		volt_div,
		find_div_comb

	export
		X_L__2__L,
		L__2__X_L,
		L__X_L__2__f,
		C__2__X_C,
		X_C__2__C,
		dBm__2__W,
		dBm__2__V,
		W__2__dBm,
		V__2__dBm



	E_series = Dict(
		"E12" => [
			1.0, 1.2, 1.5, 1.8,
			2.2, 2.7,
			3.3, 3.9,
			4.7,
			5.6,
			6.8,
			8.2
		],
		"E24" => [
			1.0, 1.1, 1.2, 1.3, 1.5, 1.6, 1.8,
			2.0, 2.2, 2.4, 2.7,
			3.0, 3.3, 3.6, 3.9,
			4.3, 4.7,
			5.1, 5.6,
			6.2, 6.8,
			7.5,
			8.2,
			9.1,
		],
		"E48" => [
			1.00, 1.05, 1.10, 1.15, 1.21, 1.27, 1.33, 1.40, 1.47, 1.54, 1.62, 1.69, 1.78, 1.87, 1.96,
			2.05, 2.15, 2.26, 2.37, 2.49, 2.61, 2.74, 2.87,
			3.01, 3.16, 3.32, 3.48, 3.65, 3.83,
			4.02, 4.22, 4.42, 4.64, 4.87,
			5.11, 5.36, 5.62, 5.90,
			6.19, 6.49, 6.81,
			7.15, 7.50, 7.87,
			8.25, 8.66,
			9.09, 9.53, 
		],
		"E96" => [
			1.00, 1.02, 1.05, 1.07, 1.10, 1.13, 1.15, 1.18, 1.21, 1.24, 1.27, 1.30, 1.33, 1.37,
			1.40, 1.43, 1.47, 1.50, 1.54, 1.58, 1.62, 1.65, 1.69, 1.74, 1.78, 1.82, 1.87, 1.91, 1.96,
			2.00, 2.05, 2.10, 2.16, 2.21, 2.26, 2.32, 2.37, 2.43, 2.49, 2.55, 2.61, 2.67, 2.74, 2.80, 2.87, 2.94,
			3.01, 3.09, 3.16, 3.24, 3.32, 3.40, 3.48, 3.57, 3.65, 3.74, 3.83, 3.92,
			4.02, 4.12, 4.22, 4.32, 4.42, 4.53, 4.64, 4.75, 4.87, 4.99,
			5.11, 5.23, 5.36, 5.49, 5.62, 5.76, 5.90,
			6.04, 6.19, 6.34, 6.49, 6.65, 6.81, 6.98,
			7.15, 7.32, 7.50, 7.68, 7.87,
			8.06, 8.25, 8.45, 8.66, 8.87,
			9.09, 9.31, 9.53, 9.76, 
		]
	)


	using Reexport
	@reexport using Units


	struct R
		R::Float64
		P::Float64
		constr::Vector{R}
	end

	R(R_, P_ = NaN) = R(R_, P_, R[])

	is_leaf(r) = isempty(r.constr)

	import Base: show, +, -, *, |, /, ==, <, hash

	function show(io::IO, r::R)
		print(io, "$(r.R)Ω", !isnan(r.P) ? " $(r.P)W" : "")
	end

	function +(r1::R, r2::R)::R
		r3_R = r1.R + r2.R
		r3 = R(
			r3_R,
			min(r3_R*r1.P/r1.R, r3_R*r2.P/r2.R),
			R[r1, r2]
		)
		return r3
	end
	function -(r1::R, r2::R)::R
		r3_R = r1.R - r2.R
		r3 = R(
			r3_R,
			#TODO
		)
		return r3
	end

	function *(n::Number, r1::R)::R
		@assert(n >= 1)
		r_acc = R(
			n*r1.R,
			n*r1.P,
			fill(r1, n)
		)
		return r_acc
	end

	function |(r1::R, r2::R)::R
		r3_R = r1.R*r2.R/(r1.R + r2.R)
		r3 = R(
			r3_R,
			min(r1.R/r3_R*r1.P, r2.R/r3_R*r2.P),
			R[r1, r2]
		)
		return r3
	end

	function /(r1::R, r2::R)::Float64
		return r1.R/r2.R
	end

	function /(r1::R, n::Number)::R
		return R(
			r1.R/n,
			r1.P/n
		)
	end

	function ==(r1::R, r2::R)::Bool
		return r1.R == r2.R && r1.P == r2.P
	end

	function <(r1::R, r2::R)::Bool
		return r1.R < r2.R
	end

	hash(r::R, h::UInt) = hash((r.R, r.P), h)


	
	using Combinatorics_Helpers

	struct R_Comb
		R
		comb
		res
		err
	end
	
	function find_ser_comb(target_ratio, E_serie = "E24", N = 2)
		scale = 10^floor(log10(target_ratio))
		E_values = vcat(
			E_series[E_serie] .* scale,
			E_series[E_serie] .* (scale*0.1),
		)

		combs_res = R_Comb[]
		for n in 1:N
			for comb in combinations_with_repetition(E_values, n)
				res = sum(comb)
				err = abs(res - target_ratio)
				push!(
					combs_res,
					R_Comb(target_ratio, comb, res, err)
				)
			end
		end
		sort!(combs_res, by = (r) -> r.err)
		
		combs_res = filter!((r) -> r.err == combs_res[1].err, combs_res)
		@assert !isempty(combs_res)
		
		return combs_res
	end
	
	
	function find_comb(target_ratio)
		return find_ser_comb(target_ratio)[1]
	end


	function Base.show(io::IO, ::MIME"text/plain", rc::R_Comb)
		c = join(["$e" for e in rc.comb], "+")
		print(io, "$(rc.R)Ω ($c ~ $(rc.res) -> $(rc.err)%)")
	end


	L__2__X_L(L, f) = 2π*f*L
	X_L__2__L(X_L, f) = X_L/(2π*f)
	L__X_L__2__f(L, X_L) = X_L/(2π*L)

	C__2__X_C(C, f) = 1/(2π*f*C)
	X_C__2__C(X_C, f) = 1/(X_C*2π*f)

	

	dBm__2__W(dBm) = 1e-3*10^(dBm/10)
	dBm__2__V(dBm, Z0 = 50) = sqrt(dBm__2__W(dBm)*Z0)
	W__2__dBm(W) = 10*log10(W/1e-3)
	V__2__dBm(V, Z0 = 50) = W__2__dBm(V^2/Z0)

	@doc """
	@a R_high between V_in and V_out
	@a R_low between V_out and GND
	@a V_in optional
	@return ration or V_out
	"""
	function volt_div(
		;
		R_high = nothing,
		R_low = nothing,
		V_in = 1,
		V_out = nothing,
	)
		if V_out == nothing
			ratio__or__V_out = R_low/(R_low + R_high)*V_in
			return ratio__or__V_out
		elseif R_high == nothing
			R_high = R_low*(V_in/V_out - 1)
			return R_high
		end
	end
	
	function find_div_comb(target_ratio, E_serie = "E24", N = 2)
		scale = 10^floor(log10(target_ratio))
		E_values = vcat(
			E_series[E_serie] .* scale,
			E_series[E_serie] .* (scale*0.1),
		)

		combs_res = R_Comb[]
		for n in 2:N
			for comb in combinations_with_repetition(E_values, n)
				R_low = comb[1]
				R_high = sum(comb[2:end])
				res = div(R_high = R_high, R_low = R_low)
				err = abs(res - target_ratio)
				push!(
					combs_res,
					R_Comb(target_ratio, comb, res, err)
				)
			end
		end
		sort!(combs_res, by = (r) -> r.err)
		
		combs_res = filter!((r) -> r.err == combs_res[1].err, combs_res)
		@assert !isempty(combs_res)
		
		return combs_res
	end

	
end

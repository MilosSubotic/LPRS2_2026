
module Compare

	# Comparing.
	export
		mse,
		rmse,
		nmse,
		nrmse,
		rel_rmse,
		rse,
		mae,
		rel_mae,
		sae,
		re,
		d1,
		d_inf,
		mad1,
		mad_inf,
		nse,
		distance,
		zero_norm,
		mean_zero_norm,
		manhattan_norm,
		mean_manhattan_norm
		
	###########################################################################
		
	@assert VERSION >= v"1"
	
	###########################################################################
	
	using Statistics
	
	###########################################################################

	mse(x, y) = sum((x - y).^2) / length(x)
	rmse(x, y) = sqrt(sum((x - y).^2) / length(x))
	nmse(x, y) = mse(x, y)/(mean(x)*mean(y))
	# Coefficient of variation of the RMSE.
	nrmse(x, y) = rmse(x, y)/(mean(x)*mean(y))
	# These two are bad because could produce divide by zero exception.
	rel_rmse(x, y) = sqrt(sum((x - y).^2 ./ x.^2) / length(x))
	rse(x, y) = sum((x - y).^2 ./ x.^2)
	mae(x, y) = sum(abs(x - y)) / length(x)
	rel_mae(x, y) = mean(abs((x - y)./x))
	sae(x, y) = sum(abs2, x - y)
	@doc """
	2nd norm (Euclidian distance) based relative error.
	"""
	function re(x::Number, y::Number)
		d = x - y
		norm(d)^2/(norm(x)*norm(y))
	end
	@doc """
	2nd norm (Euclidian distance) based relative error.
	"""
	function re(x::Array, y::Array)
		x = x[:]
		y = y[:]
		d = x - y
		norm(d)^2/(norm(x)*norm(y))
		#dot(d, d)/sqrt(dot(x, x)*dot(y, y))
	end

	# Relative Percent Difference
	function d1(x, y)
		if x == y # Take care of infinities.
			return 0
		elseif x*y == 0 # Either a or b is zero.
			#return sign(x - y)*sqrt(abs(x - y))
			return 1
		else
			#TODO Multiply with 2.
			return (x - y)/(abs(x) + abs(y))
		end
	end
	function d_inf(x, y)
		if x == y # Take care of infinities.
			return 0
		elseif x*y == 0 # Either a or b is zero.
			#return sign(x - y)*sqrt(abs(x - y))
			return 1
		else
			return (x - y)/max(abs(x), abs(y))
		end
	end
	# Mean Absolute Relative Percent Difference
	mad1(x, y) = mean(abs.(d1.(x, y)))
	mad_inf(x, y) = mean(abs.(d_inf.(x, y)))
	# Normalized Squared Error
	function nse(actual, reconstructed)
		return sum(abs2.(actual - reconstructed))/sum(abs2.(actual))
	end
	

	distance(x, y) = norm(x - y)

	zero_norm(x, y) = norm(x - y, 0)
	mean_zero_norm(x, y) = norm(x - y, 0) / length(x)

	manhattan_norm(x, y) = norm(x - y, 1)
	mean_manhattan_norm(x, y) = norm(x - y, 1) / length(x)

	###########################################################################

end


module Combinatorics_Helpers
	
	export
		combinations_without_repetition,
		num_combinations_without_repetition,
		combinations_with_repetition,
		num_combinations_with_repetition,
		variations_without_repetition,
		num_variations_without_repetition,
		variations_with_repetition,
		num_variations_with_repetition
	
	###########################################################################

	# Terminology:
	# http://users.telenet.be/vdmoortel/dirk/Maths/PermVarComb.html
	
	###########################################################################

	using Utils
	install_if_not_installed(["Combinatorics"])

	using Combinatorics
	#using Iterators
	
	###########################################################################
	
	@doc raw"""
	Combinations with repetition.
	Pick without repetation.
	Order is not important.
	"""
	function combinations_without_repetition(a, p::Integer)
		return combinations(a, p)
	end
	@doc raw"""
	```math
	C^n_p = \frac{n!}{p!(n-p)!}
	```
	"""
	function num_combinations_without_repetition(a, p::Integer)::Integer
		n = length(a)
		return binomial(n, p)
	end
	
	@doc raw"""
	Combinations with repetition.
	Pick with repetation.
	Order is not important.
	"""
	function combinations_with_repetition(a, p::Integer)
		return multiset_combinations(repeat(a, p), p)
	end
	@doc raw"""
	```math
	\overline{C}^n_p = C^{n+p-1}_p
	```
	"""
	function num_combinations_with_repetition(a, p::Integer)::Integer
		n = length(a)
		return binomial(n+p-1, p)
	end

	@doc raw"""
	Variations without repetition.
	Pick and arrange without repetation.
	Kind a permutation without need to use all elements.
	Order is important.
	"""
	function variations_without_repetition(a, n::Integer)
		#FIXME Not the fastest.
		# Need to make custom reduce iterator,
		# which will iterate over Combinatorics.Permutations iterators. 
		return reduce(
			vcat,
			collect.(
				Base.Generator(
					(x) -> permutations(x),
					combinations_without_repetition(a, n)
				)
			)
		)
	end
	@doc raw"""
	```math
	V^n_p = P^n_p = \frac{n!}{(n-p)!}
	```
	"""
	function num_variations_without_repetition(a, n::Integer)
		n = length(a)
		return binomial(n, p)*factorial(p)
	end
	
	@doc raw"""
	Variations with repetition.
	Pick and arrange with repetation.
	Kind a permutation without need to use all elements.
	Order is important (besides for same symbol).
	"""
	function variations_with_repetition(a, n::Integer)
		return Base.Generator(
			(x) -> [x...],
			Iterators.product(fill(a, n)...)
		)
	end
	@doc raw"""
	```math
	\overline{V}^n_p = n^p
	```
	"""
	function num_variations_with_repetition(a, n::Integer)
		return length(a) ^ n
	end
	
	###########################################################################
end

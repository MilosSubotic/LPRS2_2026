
module Utils

	# Helpers.
	export
		@export_enum,
		@rel_using,
		@must_specify,
		msg,
		@display,
		prompt,
		prompt_answers,
		Prompt_Option,
		prompt_select,
		install_if_not_installed
	
	# Constants.
	export
		c0
	
	# Iterations.
	export
		progress,
		timed_progress,
		inc_file_name,
		repeat_elems,
		range_rand,
		unzip,
		linspace2d,
		logrange,
		multidim_iter

	# Algo
	export
		find_closest
	
	# Fun call count.
	export
		@counted,
		get_fun_call_count,
		reset_fun_call_count,
		reset_all_funs_call_count
		
	# Signal stuff.
	export
		wrap,
		mix,
		linear_interpolation
	
	# Numeric stuff.
	export
		clamp!,
		clamp_neg,
		round,
		ceil,
		bool
	
	# Filesystem stuff.
	export
		glob,
		check_file,
		gen_nick_names,
		format_timestamp,
		ctor_timestamp,
		parse_timestamp
		
	###########################################################################
		
	@assert VERSION >= v"1"
	
	###########################################################################
	
	using Statistics
	using Printf
	using Dates
	
	###########################################################################
	
	macro export_enum(enum)
		Expr(
			:block,
			Expr(
				:call,
				Expr(:., __module__, :(:eval)),
				Expr(:export, enum)
			),
			Expr(
				:for,
				Expr(:(=), :s, Expr(:call, :instances, esc(enum))),
				Expr(
					:call,
					Expr(:., __module__, :(:eval)),
					Expr(
						:call,
						:Expr,
						:(:export),
						Expr(:call, :Symbol, :s)
					)
				)
			)
		)
	end
	
	macro rel_using(path_to_module, module_name)
		quote
			p = $path_to_module
			if !isabspath(p)
				dir_of_one_calling_this = dirname(
					string(
						$(
							QuoteNode(__source__.file)
						)
					)
				)
				p = joinpath(dir_of_one_calling_this, p)
			end
			push!(LOAD_PATH, p)
			m = $(string(module_name))
			$__module__.eval(
				Meta.parse(
					"using $m"
				)
			)
			#TODO Maybe is not last.
			#TODO Do not push if already exists on start.
			pop!(LOAD_PATH)
		end
	end
	
	macro must_specify(var)
		quote
			throw(ArgumentError("must specify " * $(string(var))))
		end
	end
	
	###########################################################################
	
	struct ExitException <: Exception
		ret_code::Int
	end

	@enum MsgType VERB DEBUG INFO WARN ERROR FATAL
	@export_enum MsgType

	function msg(
		msg_type::MsgType,
		args...
	)
		if msg_type == VERB
			color = Base.text_colors[:white]
			msg_type_str = "verbose"
		elseif msg_type == DEBUG
			color = Base.text_colors[:light_green]
			msg_type_str = "debug"
		elseif msg_type == INFO
			color = Base.text_colors[:light_blue]
			msg_type_str = "info"
		elseif msg_type == WARN
			color = Base.text_colors[:light_yellow]
			msg_type_str = "warning"
		elseif msg_type == ERROR
			color = Base.text_colors[:light_red]
			msg_type_str = "error"
		elseif msg_type == FATAL
			color = Base.text_colors[:light_red]
			msg_type_str = "fatal"
		end

		#TODO print_with_color does not work.
		print(
			color,
			msg_type_str, ": ",
			args..., '\n',
			Base.color_normal
		)

		if msg_type == FATAL
			throw(ExitException(1))
		end
	end

	###########################################################################
	
	macro display(var)
		quote
			println($(string(var)), " =")
			display($(esc(var)))
			println()
		end
	end
	
	
	###########################################################################	
	
	function prompt(msg)::Char
		print(msg, ' ')
		cmd = `bash -c 'read -n 1 char; echo -n $char'`
		procs = open(cmd, "r", stdin)
		bytes = read(procs.out)
		success(procs) || pipeline_error(procs)
		str = String(bytes)
		if length(str) == 0
			c = '\n'
		else
			c = str[1]
		end
		println("")
		return c
	end
	
	function prompt_answers(msg, answers)
		while true
			c = prompt(msg)
			if c in answers
				return c
			end
		end
	end

	
	struct Prompt_Option
		key::Char
		msg::String
		exec::Function
	end
	
	mutable struct Priv_Prompt_Option
		opt::Prompt_Option
		done::Bool
	end
	Priv_Prompt_Option(opt::Prompt_Option) = Priv_Prompt_Option(opt, false)


	@doc """
		@return true if done, false if quit
	"""
	function prompt_select(
		;
		header_msg::String,
		options::Vector{Prompt_Option},
	)::Bool
		#TODO msg(ERROR, "Have multiple options with same key!")
		#TODO msg(ERROR, "Have multiple options with same msg!")
		#TODO msg(ERROR, "Have multiple options with same exec!")
		priv_options = map(Priv_Prompt_Option, options)

		while true
			all_done = all([po.done for po in priv_options])

			msg = header_msg * "\n"
			for po in priv_options
				msg *= "\t$(po.opt.key) to select $(po.opt.msg)"
				if po.done
					msg *= " DONE"	
				end
				msg *= "\n"
			end
			msg *= "\tq to quit\n"
			if all_done
				msg *= "\td for done\n"
			end
			msg *= "answer> "

			c = lowercase(prompt(msg))
			if c in "q"
				println("Quit :(")
				return false
			end
			if all_done
				if c in "d"
					println("Done O 성공")
					return true
				end
			end

			selected_po = nothing
			for po in priv_options
				if c == po.opt.key
					selected_po = po
					break
				end
			end

			if selected_po != nothing
				selected_po.opt.exec(selected_po.opt)
				selected_po.done = true
			else
				println("Wrong selection X 실패")
			end
		end
	end

	###########################################################################	
	
	import Pkg
	function install_if_not_installed(pkgs::Vector{String})
		deps = Pkg.dependencies()
		#all_pkgs = String[dep.name for dep in values(deps)]
		installed_pkgs = String[
			dep.name for dep in values(deps)
				if dep.is_direct_dep && dep.version !== nothing
		]
		for pkg in pkgs
			m = match(r"https://.*/(\w+)\.jl", pkg)
			if m != nothing
				pkg_name = m[1]
				install = () -> Pkg.add(url = pkg)
			else
				pkg_name = pkg
				install = () -> Pkg.add(pkg)
			end

			if !(pkg_name in installed_pkgs)
				println("Installing $pkg_name...")
				install() 
			end
		end
	end

	###########################################################################	
	
	const c0 = 299792458 # [m/s]
	

	###########################################################################

	struct Progress{I}
		itr::I
		fmt_msg::Function
		N::Int
	end
	
	function default_progress_fmt_msg(progress)
		println("Done: ", progress, '%')
	end

	"""
		progress(iter, [fmt_msg::Function])

	An iterator which yield what `iter` would be,
	but track progress and print it on console output.

	# Examples
	```jldoctest
	julia> a = 1:4;

	julia>  for aa in progress(a)
				@show aa
			end
	Done: 0%
	1
	Done: 25%
	2
	Done: 50%
	3
	Done: 75%
	4
	```
	"""
	function progress(iter, fmt_msg::Function = default_progress_fmt_msg)
		Progress(iter, fmt_msg, length(iter))
	end

	Base.length(e::Progress) = length(e.itr)
	Base.size(e::Progress) = size(e.itr)
	function Base.iterate(e::Progress, state = (0,))
		i, rest = state[1], Base.tail(state)
		n = iterate(e.itr, rest...)
		if n === nothing
			e.fmt_msg(100)
			return n
		else
			prev_prog = div(100*(i-1), e.N)
			prog = div(100*i, e.N)
			if prev_prog != prog
				e.fmt_msg(prog)
			end
			return n[1], (i+1, n[2])
		end
	end

	Base.eltype(::Type{Progress{I}}) where {I} = Tuple{Int, eltype(I)}

	Base.IteratorSize(::Type{Progress{I}}) where {I} = IteratorSize(I)
	Base.IteratorEltype(::Type{Progress{I}}) where {I} = IteratorEltype(I)



	mutable struct TimedProgress{I}
		itr::I
		fmt_msg::Function
		N::Int
		ts_start::UInt64
		ts_last::UInt64
		t_per_iters::Vector{UInt64}
	end
	
	function default_timed_progress_fmt_msg(progress, t_remain, t_pass)
		function hour_min_sec(t)
			min, sec = divrem(t, 60)
			hour, min = divrem(round(Int, min), 60)
			return hour, min, sec
		end
		function print_t(name, t)
			if isinf(t)
				return @sprintf("%s: - ", name)
			else
				h, m, s = hour_min_sec(t)
				return @sprintf(
					"%s: %4d hours %2d mins %6.3f sec  ",
					name, h, m, s
				)
			end
		end
		msg(
			INFO,
			@sprintf("Done: %3d%%  ", progress),
			print_t("Remain", t_remain),
			print_t("Passed", t_pass),
		)
	end

	"""
	timed_progress(iter, [fmt_msg])

	An iterator which yield what `iter` would be,
	but track timed_progress, print it on console output
	and estimate time until end.

	# Examples
	```jldoctest
	julia> a = 1:4;

	julia>  for aa in timed_progress(a)
				@show aa
			end
	Done: 0%
	1
	Done: 25%
	2
	Done: 50%
	3
	Done: 75%
	4
	```
	"""
	function timed_progress(
		iter,
		fmt_msg::Function = default_timed_progress_fmt_msg
	)
		TimedProgress(
			iter,
			fmt_msg,
			length(iter),
			time_ns(),
			UInt64(0),
			UInt64[]
		)
	end
	
	function inc_file_name(dir, base, ext, digits = 4)
		function replace_regex_stuff!(s)
			d = Dict(
				"." => raw"\."
			)
			for (old, new) in d
				s = replace(s, old => new)
			end
		end
		replace_regex_stuff!(base)
		replace_regex_stuff!(ext)
	
		r = Regex(base * raw"(\d+)" * ext)
		l = readdir(dir)
		l = [f for f in l if match(r, f) != nothing]
		sort!(l)
		if isempty(l)
			new_i = 1
		else
			f = l[end]
			ma = match(r, f)
			i = parse(Int, ma[1])
			new_i = i + 1
		end
		new_i_s = Printf.format(Printf.Format("%0$(digits)d"), new_i)
		new_base = base * new_i_s
		return dir, new_base, ext, new_i
	end

	@doc """
		@return new fn, new idx
	"""
	function inc_file_name(fn, digits = 4)
		dir = dirname(fn)
		base, ext = splitext(basename(fn))
		dir, new_base, ext, new_i = inc_file_name(dir, base, ext, digits)
		return joinpath(dir, new_base * ext), new_i
	end
	

	Base.length(e::TimedProgress) = length(e.itr)
	Base.size(e::TimedProgress) = size(e.itr)
	function Base.iterate(e::TimedProgress, state = (0,))
		i, rest = state[1], Base.tail(state)
		n = iterate(e.itr, rest...)
		ts_now = time_ns()
		t_passed = ts_now - e.ts_start
		t_last_iter = ts_now - e.ts_last
		e.ts_last = ts_now
		if n === nothing
			e.fmt_msg(100, 0, t_passed*1e-9)
			return n
		else
			prev_prog = div(100*(i-1), e.N)
			prog = div(100*i, e.N)
			if prev_prog != prog
				if i != 0
					#@show i
					#@show t_last_iter
					push!(e.t_per_iters, t_last_iter)
					#@show e.t_per_iters
					if length(e.t_per_iters) == 1
						t_mean = t_last_iter
					else
						t_mean = mean(e.t_per_iters[2:end])
					end
					remain_iters = e.N - i
					t_remain = t_mean*remain_iters
				else
					t_remain = Inf
				end
				e.fmt_msg(prog, t_remain*1e-9, t_passed*1e-9)
			end
			return n[1], (i+1, n[2])
		end
	end

	Base.eltype(::Type{TimedProgress{I}}) where {I} = Tuple{Int, eltype(I)}

	Base.IteratorSize(::Type{TimedProgress{I}}) where {I} = IteratorSize(I)
	Base.IteratorEltype(::Type{TimedProgress{I}}) where {I} = IteratorEltype(I)


	###########################################################################

	function repeat_elems(
		a::AbstractArray{T},
		n::Integer
	) where {
		T <: Number
	}
		kron(a, ones(T, n))
	end

	function range_rand(
		min::Union{T, Vector{T}},
		max::Union{T, Vector{T}},
		n::Integer
	) where {
		T <: AbstractFloat
	}
		rand(T, n).*(max - min) .+ min
	end

	function range_rand(
		min::Vector{T},
		max::Vector{T},
		n::Integer
	) where {
		T <: Integer
	}
		x = Vector{T}(n)
		for i in 1:n
			x[i] = rand(min[i]:max[i])
		end
		x
	end
	function range_rand(
		min::T,
		max::T,
		n::Integer
	) where {
		T <: Integer
	}
		rand(min:max, n)
	end

	function unzip(input::Array)
		s = size(input)
		types  = map(typeof, first(input))
		output = map(T->Array{T}(undef, s), types)

		for i = 1:length(input)
			@inbounds for (j, x) in enumerate(input[i])
				(output[j])[i] = x
			end
		end

		return output
	end

	function linspace2d(start, stop, len=100)
		# TODO Optimize.
		axis = collect(linspace(start, stop, len))
		xs = kron(axis, ones(eltype(axis), 1, len))
		ys = xs'
		xys = map((x, y)-> [x, y], xs, ys)
		return xys
	end

	function logrange(start, stop; length) 
		return exp10.(range(log10(start), log10(stop), length = length))
	end



	struct _Iter
		ai::Vector{Int}
	end
	_Iter(i::Int) = _Iter([i])
	import Base.*
	(*)(i1::_Iter, i2::_Iter) = _Iter(vcat(i1.ai, i2.ai))
	function multidim_iter(array_of_ranges)
	
		dims = length(array_of_ranges)
		collections = []
		for i in 1:dims
			push!(
				collections,
				map(
					_Iter,
					collect(array_of_ranges[i]))
				)
		end
		iters = kron(collections...)
		iters = map((i) -> i.ai, iters)
	
		return iters
	end
	

	###########################################################################

	function find_closest(target, a; by = (x) -> x)
		ias = collect(enumerate(a))
		closest_ia = first(
			sort(
				ias,
				by = (ia) -> abs(target - by(ia[2])) /
					max(abs(target), abs(by(ia[2])))
			)
		)
		return closest_ia
	end
	
	###########################################################################

	#FIXME Is this somewhere else?
	_fun_call_counters = Dict{String, Int}()
	_fun_to_idx = Dict{Any, Int}()
	_idx_to_cnt = Vector{Int}()
	macro counted(f)
		if f.head == :(=)
			if f.args[1].head == :call
				body = f.args[2]
			end
		elseif f.head == :function
			# f.args[1].head == :call || f.args[1].head == :tuple
			body = f.args[2]
		end
		
		push!(Utils._idx_to_cnt, 0)
		idx = length(Utils._idx_to_cnt)
		
		counter_code = quote
			Utils._idx_to_cnt[$idx] += 1
		end
		insert!(body.args, 1, counter_code)
		
		ef = __module__.eval(f)
		
		Utils._fun_to_idx[ef] = idx
		
		return ef
	end

	function get_fun_call_count(fun)
		return _idx_to_cnt[_fun_to_idx[fun]]
	end
	function reset_fun_call_count(fun)
		_idx_to_cnt[_fun_to_idx[fun]] = 0
		return nothing
	end
	function reset_all_funs_call_count()
		_idx_to_cnt .= 0
		return nothing
	end

	###########################################################################

	# For unwrap(), use DSP package.

	function wrap(n::T)::T where {T <: Number}
		while n > π
			n -= 2π
		end
		while n < -π
			n += 2π
		end
		return n
	end

	mix(x, y, a) = x*(1-a) + y*a

	function linear_interpolation(
		src::AbstractArray{T},
		scale::Number
	) where {
		T <: Number
	}

		N_src = length(src)
		N_dst = round(Int, scale*N_src)
		ratio = (N_src - 1) / (N_dst - 1)

		dst = Vector{T}(N_dst)

		for idx_dst in 0:N_dst-1
			(weight_h, src_l) = modf(idx_dst*ratio)
			weight_l = 1 - weight_h
			src_h = src_l + 1
			idx_src_l = floor(Int, src_l)
			idx_src_h = min(ceil(Int, src_h), N_src-1)

			dst[idx_dst+1] =
				src[idx_src_l+1]*weight_l + src[idx_src_h+1]*weight_h
		end

		dst
	end

	###########################################################################
	
	import Base: clamp!
	#=
	#FIXME Use Base.clamp.()
	function clamp(
		x::Vector,
		lo::Vector,
		hi::Vector,
	)
		y = copy(x)
		@assert length(y) == length(lo)
		@assert length(y) == length(hi)
		for i in 1:length(y)
			@assert lo[i] <= hi[i]
			if y[i] < lo[i]
				y[i] = lo[i]
			elseif y[i] > hi[i]
				y[i] = hi[i]
			end
		end
		y
	end
	=#
	function clamp!(
		x::AbstractArray,
		lo::AbstractArray,
		hi::AbstractArray,
	)
		@assert length(x) == length(lo)
		@assert length(x) == length(hi)
		for i in 1:length(x)
			@assert lo[i] <= hi[i]
			if x[i] < lo[i]
				x[i] = lo[i]
			elseif x[i] > hi[i]
				x[i] = hi[i]
			end
		end
	end
	clamp_neg(x) = max(x, 0)

	import Base: round, ceil
	round(t::Type{T}, f::AbstractFloat) where {T <: AbstractFloat} = T(f)
	ceil(t::Type{T}, f::AbstractFloat) where {T <: AbstractFloat} = T(f)
	
	bool(x::Int) = x != 0
	bool(x::Nothing) = false
	bool(x::UnitRange{Int}) = x != 0:-1

	###########################################################################

	function glob(g)
		r = read(`bash -c "ls -d -w1 $g | tee"`)
		s = chomp(String(r))
		if s == ""
			list = String[]
		else
			list = Vector{String}(split(s, "\n"))
		end
		return list
	end

	function check_file(file_name)
		if isdir(file_name)
			msg(FATAL, "Dir \"$file_name\" is not a file!")
		end
		if !isfile(file_name)
			msg(FATAL, "File \"$file_name\" does not exists!")
		end
	end

	@doc """
		Make name shorter by removing common part.
		@return common_name, nick_names
	"""
	function gen_nick_names(
		names::Vector{T},
		separator::AbstractString
	) where {
		T <: AbstractString
	}
		common_name = ""
		
		s1 = separator
		s2 = s1^2
		function recursive_split(name)
			splited_name = Vector{String}[]
			for n2 in split(name, s2)
				push!(splited_name, String[])
				for n1 in split(n2, s1)
					push!(splited_name[end], n1)
				end
			end
			return splited_name
		end
		function recursive_join(splited_name)
			j = [join(n2, s1) for n2 in splited_name]
			jf = filter(n1 -> n1 != "", j)
			name = join(jf, s2)
			return name
		end
		
		table = Dict{String, Int}()
		splited_names = map(recursive_split, names)
		for n in splited_names
			for n2 in n
				for n1 in n2
					if !haskey(table, n1)
						table[n1] = 1
					else
						table[n1] += 1
					end
				end
			end
		end
		
		N = length(names)
		common = Set{String}()
		for (n1, count) in table
			if count == N
				push!(common, n1)
			end
		end
		
		nick_names = String[]
		splited_common_name = Vector{String}[]
		splited_nick_names = Vector{Vector{String}}[]
		for n in splited_names
			push!(splited_nick_names, Vector{String}[])
			for (i2, n2) in enumerate(n)
				push!(splited_nick_names[end], String[])
				for n1 in n2
					if n1 in common
						# Add to common.
						while length(splited_common_name) < i2
							push!(splited_common_name, String[])
						end
						if !(n1 in splited_common_name[i2])
							push!(splited_common_name[i2], n1)
						end
					else
						# Add to nick name.
						push!(splited_nick_names[end][end], n1)
					end
				end
			end
		end
		
		
		common_name = recursive_join(splited_common_name)
		nick_names = map(recursive_join, splited_nick_names)
		
		return common_name, nick_names
	end

	TIMESTAMP_FORMAT = dateformat"yyyy-mm-dd--HH-MM-SS--sss"
	const Timestamp = AbstractString
	
	function format_timestamp(t::DateTime)::Timestamp
		timestamp = Dates.format(t, TIMESTAMP_FORMAT)
		return timestamp
	end
	function ctor_timestamp()::Timestamp
		t = Dates.now()
		timestamp = format_timestamp(t)
		return timestamp
	end
	function parse_timestamp(timestamp::Timestamp)::DateTime
		return DateTime(timestamp, TIMESTAMP_FORMAT)
	end

	###########################################################################

end

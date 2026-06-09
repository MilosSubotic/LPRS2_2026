

export 
	SV_CPU,
	@write_var,
	@read_var!,
	load_fw,
	run,
	end_of_program,
	@write_scalar_var,
	@show_scalar_var


using DelimitedFiles


push!(LOAD_PATH, joinpath(@__DIR__))
push!(LOAD_PATH, joinpath(@__DIR__, "../../../FW/Compiler/Config_CPU/tools/"))
unique!(LOAD_PATH)
import sv_cpu_cfg
using Hex_Parser


const word_t = UInt64
const addr_t = UInt32 # [W]

mutable struct SV_CPU
	portal::Portal_Worm
	map::Dict{String, addr_t}
	timeout_s
	verbose
end



function write_word(cpu::SV_CPU, addr_W, val)
	data = word_t[reinterpret(word_t, val)]
	write(
		cpu.portal,
		UInt32(addr_W*sizeof(word_t)),
		data
	)
end

function read_word(cpu::SV_CPU, addr_W, t::Type = word_t)
	data = zeros(word_t, 1)
	read!(
		cpu.portal,
		UInt32(addr_W*sizeof(word_t)),
		data
	)
	return reinterpret(t, data[1])
end


SDATA_BASE = sv_cpu_cfg.SDATA_UA << sv_cpu_cfg.SDATA_CW # [W]
VDATA_BASE = sv_cpu_cfg.VDATA_UA << sv_cpu_cfg.VDATA_CW # [W]
DM_end_of_program = SDATA_BASE
end_of_program(cpu::SV_CPU) = read_word(cpu, DM_end_of_program)


function SV_CPU(
	portal::Portal_Worm
	;
	timeout_s = 1,
	verbose = false,
)
	cpu = SV_CPU(
		portal,
		Dict{String, addr_t}(),
		timeout_s,
		verbose,
	)

	# Does not quite work as expected.
	if false
		finalizer(
			function(cpu::SV_CPU)
				println("finilizing SV_CPU...")
				close(cpu)
			end,
			cpu
		)
	end

	if cpu.verbose
		@assert read_word(cpu, sv_cpu_cfg.RM_magic) == sv_cpu_cfg.MAGIC
		version = read_word(cpu, sv_cpu_cfg.RM_version)
		version_major = Int8(version >> 8 & 0xff)
		version_minor = Int8(version >> 0 & 0xff)
		@show version_major
		@show version_minor
	end

	return cpu
end

mutable struct Chunk
	addr::addr_t # [W]
	words::Vector{word_t}
end

function load_fw(cpu::SV_CPU, fn::String)
	d = dirname(fn)
	f, e = splitext(basename(fn))
	if e == ".asm"

		asm = joinpath(@__DIR__, "../../../FW/asm.sh")
		run(`$asm $fn 0`)

		build_dir = joinpath(d, "build")
		hex_fn = joinpath(build_dir, f * ".hex")
	elseif e == ".hex"
		hex_fn = fn
	else
		throw(ArgumentError("Not supported extension \"$e\"!"))
	end

	f, e = splitext(hex_fn)
	map_fn = f * ".map"

	name, _ = splitext(basename(hex_fn))

	machine_code, word_B = parse_hex_file(hex_fn)

	if word_B != nothing
		@assert word_B == sizeof(word_t)
	end

	#TODO Better chunk it.
	machine_code_chinks = Chunk[]
	addr = 0
	chunk = nothing
	for (i, (a, ws)) in enumerate(machine_code)
		w = parse(word_t, ws, base = 16)
		if i == 1
			addr = a
			chunk = Chunk(addr, word_t[w])
		else
			if a != addr
				push!(machine_code_chinks, chunk)
				addr = a
				chunk = Chunk(addr, word_t[w])
			else
				push!(chunk.words, w)
			end
		end
		addr += 1
	end
	if chunk != nothing
		push!(machine_code_chinks, chunk)
	end

	# Read map
	map = Dict{String, addr_t}()
	if filesize(map_fn) != 0
		t = readdlm(map_fn, ' ', String)
		for r in 1:size(t)[1]
			addr = parse(addr_t, t[r, 1], base = 16)
			@assert t[r, 2] == "d"
			var_name = t[r, 3]
			map[var_name] = addr
		end
	end

	cpu.map = map
	

	for chunk in machine_code_chinks
		write(
			cpu.portal,
			UInt32(chunk.addr*sizeof(word_t)),
			chunk.words
		)
	end

	if cpu.verbose
		println("Finished loading machine code!")
	end
end

import Base: run
function run(cpu::SV_CPU)
	function t_elapsed_s()
		t_curr_ns = time_ns()
		return (t_curr_ns - t_start_ns)*1e-9
	end

	if cpu.verbose
		println("Start of program!")
	end
	t_start_ns = time_ns()
	# Clear end_of_program flag before start.
	write_word(cpu, DM_end_of_program, 0)
	write_word(cpu, sv_cpu_cfg.RM_n_sw_rst, 1)

	#@show read_word(cpu, RM_pc)
	while true
		if cpu.verbose
			@show t_elapsed_s()
			pc = Int(read_word(cpu, sv_cpu_cfg.RM_pc))
			@show pc
		end

		sleep(10m)
		if true
			if read_word(cpu, sv_cpu_cfg.RM_exc) != 0
				println("ERROR: EXCEPTION!")
				@show read_word(cpu, sv_cpu_cfg.RM_exc)
				break
			end
		end

		if end_of_program(cpu) != 0
			if cpu.verbose
				println("End of program in $(t_elapsed_s()) s")
			end
			break
		end

		if cpu.timeout_s != nothing
			if t_elapsed_s() > cpu.timeout_s
				println("ERROR: TIMOUT after $(t_elapsed_s()) s")
				break
			end
		end
	end

	perf_cnt = read_word(cpu, sv_cpu_cfg.RM_perf_cnt)

	write_word(cpu, sv_cpu_cfg.RM_n_sw_rst, 0)

	return perf_cnt, perf_cnt*sv_cpu_cfg.F_ALU 
end


function get_var_addr(cpu::SV_CPU, var_name::String)
	if !haskey(cpu.map, var_name)
		error("Non existing variable name \"$var_name\"!")
	else
		return UInt32(cpu.map[var_name]*sizeof(word_t)) # [B]
	end
end

function write_var(
	cpu::SV_CPU,
	var_name::String,
	data::Array
)
	write(
		cpu.portal,
		get_var_addr(cpu, var_name),
		data
	)
end
function write_var(
	cpu::SV_CPU,
	var_name::String,
	data::Number
)
	write(
		cpu.portal,
		get_var_addr(cpu, var_name),
		[data]
	)
end

macro write_var(cpu, var)
	quote
		write_var(
			$(esc(cpu)),
			$(string(var)),
			$(esc(var)),
		)
	end
end

function read_var!(
	cpu::SV_CPU,
	var_name::String,
	data::Array
)
	read!(
		cpu.portal,
		get_var_addr(cpu, var_name),
		data
	)
end

macro read_var!(cpu, var)
	quote
		read_var!(
			$(esc(cpu)),
			$(string(var)),
			$(esc(var)),
		)
	end
end

macro write_scalar_var(cpu, var, val)
	quote
		write_var(
			$(esc(cpu)),
			$(string(var)),
			$(esc(val)),
		)
	end
end

macro show_scalar_var(cpu, var, type)
	quote
		$var = zeros(type, 1)
		read_var!(
			$(esc(cpu)),
			$(string(var)),
			$var,
		)
		$var = $var[1]
		@show $var
	end
end



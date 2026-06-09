#!/usr/bin/env julia
###############################################################################


#unique!(push!(LOAD_PATH, joinpath(@__DIR__, "..")))
#using Portal
include("../Portal_inc.jl")


#prog = "../../FW/test__cpu/build/021__add_vec.sv.hex"
prog = "$(@__DIR__)/../../../FW/test__cpu/021__add_vec.sv.asm"

portal = Portal_Wormhole(BACKEND_USB, PG_SV_CPU)
try
	cpu = SV_CPU(portal)
	global x, y, z

	load_fw(cpu, prog)
	#@show get_var_addr(cpu, "z")


	x = collect(10:10:40)
	y = collect(100:100:400)
	z = ones(Int, 4)
	@assert sizeof(eltype(x)) == 8
	
	@write_var(cpu, x)
	@write_var(cpu, y)
	run(cpu)

	@read_var!(cpu, z)

	@show z
	@assert x+y == z

finally
	close(portal)
end

println("End")


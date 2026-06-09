#!/usr/bin/env julia
##############################################################################

if isinteractive()
	empty!(Base.ARGS)
	push!(Base.ARGS, "9")
end

using ArgParse

s = ArgParseSettings()
@add_arg_table! s begin
	"--e-series", "-e"
		help = "E series [E12, E24, E48, E96]" #TODO Support for others
		default = "E12"
	"TARGET"
		help = "Target resistance"
		required = true
end
args = parse_args(s)


###############################################################################

push!(LOAD_PATH, joinpath(@__DIR__))
using Electronics_Helpers
using Units

###############################################################################

E_values = E_series[args["e-series"]]

target = convert(Float64, parse(NumberUnit, args["TARGET"]))
combs_res = find_ser_comb(target)
@show combs_res


###############################################################################


export 
	DAC_Jmp,
	probe,
	set_cfg!


push!(LOAD_PATH, joinpath(@__DIR__))
unique!(LOAD_PATH)
import dac_jmp_cfg

#TODO Inherit interface
struct DAC_Jmp
	portal::Portal_Wormhole
end

#TODO Make common. Instead of PG_ use function.
function write(dac::DAC_Jmp, addr::UInt32, data::Array)
	write(dac.portal, addr, data)
end

function read!(dac::DAC_Jmp, addr::UInt32, data::Array)
	read!(dac.portal, addr, data)
end

function write_word(dac::DAC_Jmp, addr_W, val)
	data = UInt32[reinterpret(UInt32, val)]
	write(
		dac.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
end

function read_word(dac::DAC_Jmp, addr_W, t::Type = UInt32)
	data = zeros(UInt32, 1)
	read!(
		dac.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
	return reinterpret(t, data[1])
end


function probe(dac::DAC_Jmp)::Bool
	return read_word(dac, dac_jmp_cfg.RM_probe)
end

function set_cfg!(
	dac::DAC_Jmp
	;
	t_pump,
	t_probe,
	f_2larmor,
	V_pump1,
	V_pump2,
	V_probe,
)
	t_to_mod(t::Number)::UInt32 = round(UInt32, dac_jmp_cfg.F_AXI*t)
	V_to_smpl(V::Number)::UInt16 = round(UInt16, V/2.5 * 2^16)

	t_pump_probe = t_pump + t_probe
	M_pump_probe = Int(t_to_mod(t_pump_probe))
	M_2larmor = Int(t_to_mod(1.0 / f_2larmor))
	ratio = M_pump_probe/M_2larmor
	ratio_needed = round(Int, ratio)
	ratio_needed &= ~1 # Even number.
	

	M_pump_probe_needed = ratio_needed*M_2larmor
	t_pump_probe_needed = M_pump_probe_needed/dac_jmp_cfg.F_AXI
	t_probe_need = t_pump_probe_needed - t_pump
	same = M_pump_probe == M_pump_probe_needed


	@show ratio
	@show ratio_needed
	@show M_pump_probe
	@show M_pump_probe_needed
	@show same
	@show t_probe/m
	@show t_probe_need/m

	write_word(dac, dac_jmp_cfg.RM_pump_mod, UInt32(M_pump_probe))
	write_word(dac, dac_jmp_cfg.RM_pump_th,  t_to_mod(t_pump))

	#TODO Correct gating.
	# - Need to be fixed 50ms
	# - Pumping in 10ms
	# - TiePie: 1μHz step to 40MHz, 3.125MHz sample?

	write_word(dac, dac_jmp_cfg.RM_jmp_mod,  UInt32(M_2larmor))
	write_word(dac, dac_jmp_cfg.RM_jmp_th,   t_to_mod(1.0/f_2larmor/2))
	write_word(dac, dac_jmp_cfg.RM_V_pump1,  UInt32(V_to_smpl(V_pump1)))
	write_word(dac, dac_jmp_cfg.RM_V_pump2,  UInt32(V_to_smpl(V_pump2)))
	write_word(dac, dac_jmp_cfg.RM_V_probe,  UInt32(V_to_smpl(V_probe)))

	write_word(dac, dac_jmp_cfg.RM_strobe, UInt32(1))
end
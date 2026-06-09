
export 
	ADC_Pmod_Poll,
	poll


push!(LOAD_PATH, joinpath(@__DIR__))
unique!(LOAD_PATH)
import adc_poll_cfg


struct ADC_Pmod_Poll
	portal::Portal_Wormhole
end

function write(adc::ADC_Pmod_Poll, addr::UInt32, data::Array)
	write(adc.portal, addr, data)
end

function read!(adc::ADC_Pmod_Poll, addr::UInt32, data::Array)
	read!(adc.portal, addr, data)
end

function write_word(adc::ADC_Pmod_Poll, addr_W, val)
	data = UInt32[reinterpret(UInt32, val)]
	write(
		adc.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
end

function read_word(adc::ADC_Pmod_Poll, addr_W, t::Type = UInt32)
	data = zeros(UInt32, 1)
	read!(
		adc.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
	return reinterpret(t, data[1])
end


function poll(adc::ADC_Pmod_Poll)::UInt32
	return read_word(adc, adc_poll_cfg.RM_smpl)
end

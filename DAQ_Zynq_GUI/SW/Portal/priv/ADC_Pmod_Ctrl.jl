
export 
	ADC_PMOD_CTRL,
	cnv_trig,
	cnv_progress,
	write_buf,
	read_buf!


push!(LOAD_PATH, joinpath(@__DIR__))
unique!(LOAD_PATH)
import adc_pmod_ctrl_cfg


struct ADC_PMOD_CTRL
	portal::Portal_Wormhole
end

function write(adc::ADC_PMOD_CTRL, addr::UInt32, data::Array)
	write(adc.portal, addr, data)
end

function read!(adc::ADC_PMOD_CTRL, addr::UInt32, data::Array)
	read!(adc.portal, addr, data)
end


function cnv_trig(adc::ADC_PMOD_CTRL, channel::Int, samples::Int)
	val = (channel << 30) | samples
	write(adc, adc_pmod_ctrl_cfg.CNV_TRIG_SIZE_ADDR, [UInt32(val)])
end

function cnv_progress(adc::ADC_PMOD_CTRL)::Int
	progress = Int32[-1]
	read!(adc, adc_pmod_ctrl_cfg.CNV_PROGRESS_ADDR, progress)
	return progress[1]
end

function write_buf(adc::ADC_PMOD_CTRL, ch:: Int, samples::Vector{UInt32})
	if ch < 0 || ch > 3
		error("Channel must be 1 and 2")
	elseif ch == 1
		write(adc, adc_pmod_ctrl_cfg.BUF_ADDR, samples)
	else
		write(adc, adc_pmod_ctrl_cfg.BUF1_ADDR, samples)
	end
end

function read_buf!(adc::ADC_PMOD_CTRL, ch::Int, samples::Vector{UInt32})
	if ch < 0 || ch > 3
		error("Channel must be 1 and 2")
	elseif ch == 1
		read!(adc, adc_pmod_ctrl_cfg.BUF_ADDR, samples)
	else
		read!(adc, adc_pmod_ctrl_cfg.BUF1_ADDR, samples)
	end
end

function write_word(adc::ADC_PMOD_CTRL, addr_W, val)
	data = UInt32[reinterpret(UInt32, val)]
	write(
		adc.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
end

function read_word(adc::ADC_PMOD_CTRL, addr_W, t::Type = UInt32)
	data = zeros(UInt32, 1)
	read!(
		adc.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
	return reinterpret(t, data[1])
end

function poll(adc::ADC_PMOD_CTRL)::Vector{UInt32}
    data = zeros(UInt32, 2)
    read!(adc.portal, adc_pmod_ctrl_cfg.POLL_SMPLS_ADDR, data)
    return data
end
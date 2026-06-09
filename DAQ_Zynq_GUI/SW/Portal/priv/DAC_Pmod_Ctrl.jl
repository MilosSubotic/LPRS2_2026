
export 
	DAC_PMOD_CTRL,
	cnv_trig,
	cnv_stop,
	cnv_progress,
	write_buf,
	read_buf!


push!(LOAD_PATH, joinpath(@__DIR__))
unique!(LOAD_PATH)
import dac_pmod_ctrl_cfg


struct DAC_PMOD_CTRL
	portal::Portal_Wormhole
end

function write(dac::DAC_PMOD_CTRL, addr::UInt32, data::Array)
	write(dac.portal, addr, data)
end

function read!(dac::DAC_PMOD_CTRL, addr::UInt32, data::Array)
	read!(dac.portal, addr, data)
end


function cnv_trig(dac::DAC_PMOD_CTRL, samples::Int)
	write(dac, dac_pmod_ctrl_cfg.CNV_TRIG_SIZE_ADDR, [Int32(samples)])
end

function cnv_stop(dac::DAC_PMOD_CTRL)
	write(dac, dac_pmod_ctrl_cfg.STOP_ADDR, [UInt32(1)])
end

function cnv_progress(dac::DAC_PMOD_CTRL)::Int
	progress = Int32[-1]
	read!(dac, dac_pmod_ctrl_cfg.CNV_PROGRESS_ADDR, progress)
	return progress[1]
end

function write_buf(dac::DAC_PMOD_CTRL, samples::Vector{UInt32})
	write(dac, dac_pmod_ctrl_cfg.BUF_ADDR, samples)
end

function read_buf!(dac::DAC_PMOD_CTRL, samples::Vector{UInt32})
	read!(dac, dac_pmod_ctrl_cfg.BUF_ADDR, samples)
end

function write_word(dac::DAC_PMOD_CTRL, addr_W, val)
	data = UInt32[reinterpret(UInt32, val)]
	write(
		dac.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
end

function read_word(dac::DAC_PMOD_CTRL, addr_W, t::Type = UInt32)
	data = zeros(UInt32, 1)
	read!(
		dac.portal,
		UInt32(addr_W*sizeof(UInt32)),
		data
	)
	return reinterpret(t, data[1])
end

function poll_write(dac::DAC_PMOD_CTRL, samples::Vector{UInt32})
    write(dac, UInt32(dac_pmod_ctrl_cfg.POLL_SMPL_ADDR), samples)
end

function cpu_write_done(dac::DAC_PMOD_CTRL)
	write(dac, dac_pmod_ctrl_cfg.CPU_DONE_ADDR, [UInt32(0x01)])
end

function dma_write_done(dac::DAC_PMOD_CTRL)::Int
	val = Int32[-1];
	read!(dac, dac_pmod_ctrl_cfg.DMA_DONE_ADDR, val)
	return val[1]
end

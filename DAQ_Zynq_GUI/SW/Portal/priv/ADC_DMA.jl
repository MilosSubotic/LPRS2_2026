
export 
	ADC_DMA,
	cnv_trig,
	cnv_progress,
	write_buf,
	read_buf!


push!(LOAD_PATH, joinpath(@__DIR__))
unique!(LOAD_PATH)
import adc_lvds_cfg


struct ADC_DMA
	portal::Portal_Wormhole
end

function write(adc::ADC_DMA, addr::UInt32, data::Array)
	write(adc.portal, addr, data)
end

function read!(adc::ADC_DMA, addr::UInt32, data::Array)
	read!(adc.portal, addr, data)
end


function cnv_trig(adc::ADC_DMA, samples::Int)
	write(adc, adc_lvds_cfg.CNV_TRIG_SIZE_ADDR, [Int32(samples)])
end

function cnv_progress(adc::ADC_DMA)::Int
	progress = Int32[-1]
	read!(adc, adc_lvds_cfg.CNV_PROGRESS_ADDR, progress)
	return progress[1]
end

function write_buf(adc::ADC_DMA, samples::Vector{UInt32})
	write(adc, adc_lvds_cfg.BUF_ADDR, samples)
end

function read_buf!(adc::ADC_DMA, samples::Vector{UInt32})
	read!(adc, adc_lvds_cfg.BUF_ADDR, samples)
end

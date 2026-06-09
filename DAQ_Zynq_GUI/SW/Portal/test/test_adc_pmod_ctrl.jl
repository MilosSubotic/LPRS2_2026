#!/usr/bin/env julia

include("../Portal_inc.jl")

function adc_to_mv(sample::Integer; vref = 2.5, bits = 12)
    max_value = (1 << bits) - 1
    return sample * vref * 1000 / max_value
end

function test_adc_read(gate::portal_gate_t, ch::Int, N::Int)
    portal = Portal_Wormhole(BACKEND_USB, gate)
    adc = ADC_PMOD_CTRL(portal)
    try
        
        
        cnv_trig(adc, ch, N)

        while true
            sleep(0.1)
            progress = cnv_progress(adc)
            println("Progress $progress%")
            if progress == 100
                break
            end
        end

        samples = zeros(UInt32, N)
        read_buf!(adc, ch, samples)

        println("   Index     Raw → mV values (groups of 8)\n" * "─"^60)
        for i in 1:8:min(256, N)
            print("$(lpad(i-1, 5)) → ")
            for j in 0:7
                if i + j <= length(samples)
                    raw = samples[i + j]
                    mv = adc_to_mv(raw)
                    print("$(lpad(round(mv, sigdigits=4), 10)) mV  ")
                end
            end
            println()
        end

    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(adc.portal)
    end
end

function  test_poll(gate::portal_gate_t,)
    portal = Portal_Wormhole(BACKEND_USB, gate)
    adc = ADC_PMOD_CTRL(portal)
    try
        val = poll(adc)
        mv_values = adc_to_mv.(val)
        println("Polling value: $val")
        println("Converted values: $mv_values")
    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(adc.portal)
    end
end

test_poll(PG_ADC_PMOD_1)

if true
for N in [256]
    println("Testing ADC PMOD 0 ch1 (A0) with N=$N samples")
    #test_adc_read(PG_ADC_PMOD_0, 1, N)
    sleep(1)

    println("Testing ADC PMOD 0 ch2 (A1) with N=$N samples")
    #test_adc_read(PG_ADC_PMOD_0, 2, N)
    sleep(1)

    println("Testing ADC PMOD 1 ch1 (A0) with N=$N samples")
    test_adc_read(PG_ADC_PMOD_1, 1, N)
    sleep(1)

    println("Testing ADC PMOD 1 ch2 (A1) with N=$N samples")
    #test_adc_read(PG_ADC_PMOD_1, 2, N)
end
end

println("End")
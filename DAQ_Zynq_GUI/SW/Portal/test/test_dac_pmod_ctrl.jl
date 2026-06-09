#!/usr/bin/env julia

include("../Portal_inc.jl")

const VREF_MV = 2500.0  # AD5541 Vref in mV — measure your actual Vref pin

function test_dac_write(gate::portal_gate_t, N::Int)

    portal = Portal_Wormhole(BACKEND_USB, gate)
    dac = DAC_PMOD_CTRL(portal)
    try
        # Generate a simple ramp waveform
        samples = zeros(UInt32, N)
        for i in eachindex(samples)
            # 16-bit ramp: 0 → 65535, wrapping
            samples[i] = UInt32((i - 1) * 65536 ÷ N)  # Scale to full range
        end

        println("Writing waveform buffer ($N samples)...")
        write_buf(dac, samples)

        println("Triggering DAC conversion...")
        cnv_trig(dac, N)

        while true
            sleep(0.1)
            progress = cnv_progress(dac)
            println("Progress $progress%")
            if progress >= 100
                break
            end
        end

        println("DAC playback complete.")

    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(dac.portal)
    end
end


function test_dac_sine(gate::portal_gate_t, N::Int)

    portal = Portal_Wormhole(BACKEND_USB, gate)
    dac = DAC_PMOD_CTRL(portal)
	DAC_range = 1 << 16
    try
        # Generate a sine wave scaled to 16-bit DAC range (0..65535)
        samples = zeros(UInt32, N)
        for i in eachindex(samples)
            angle = 2π * (i - 1) / N
            samples[i] = UInt32(round(32767.5 + 32767.5 * sin(angle)))
        end

        println("Writing sine waveform ($N samples)...")
        if (dma_write_done(dac) == 1)
            println("Writing $(length(samples)) samples...")
            write_buf(dac, samples)
            cpu_write_done(dac)
        else
            println("Waiting for DMA...")
        end
        println("Triggering DAC conversion...")
        cnv_trig(dac, N)
        #dma_write_done(dac)
        while true
            sleep(0.1)
            progress = cnv_progress(dac)
            println("Progress $progress%")
            if progress >= 100
                break
            end
        end

        println("DAC sine playback complete.")

    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(dac.portal)
    end
end

function test_dac_buf_readback(gate::portal_gate_t, N::Int)
    portal = Portal_Wormhole(BACKEND_USB, gate)
    dac = DAC_PMOD_CTRL(portal)
    try
        # Write known pattern
        samples_tx = zeros(UInt32, N)
        for i in eachindex(samples_tx)
            samples_tx[i] = UInt32((i - 1) % 65536)
        end

        println("Writing ramp pattern...")
        write_buf(dac, samples_tx)
        cpu_write_done(dac)

        while dma_write_done(dac) == 0
            println("Waiting for DMA write to complete...")
            sleep(0.1)
            
        end
        # Read back
        samples_rx = zeros(UInt32, N)
        read_buf!(dac, samples_rx)

        # Compare
        mismatches = 0
        for i in eachindex(samples_tx)
            if samples_tx[i] != samples_rx[i]
                mismatches += 1
                if mismatches <= 8
                    println("MISMATCH at [$i]: wrote $(samples_tx[i]), got $(samples_rx[i])")
                end
            end
        end

        if mismatches == 0
            println("Readback OK — all $N words match")
        else
            println("Readback FAILED — $mismatches mismatches out of $N")
        end

        # Show first few words regardless
        println("First 8 TX: $(Int.(samples_tx[1:8]))")
        println("First 8 RX: $(Int.(samples_rx[1:8]))")

    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(dac.portal)
    end
end

function from_mV(val::Real)::UInt32
    # Convert from mV to 16-bit DAC value (0..65535)
    # Assuming 0 mV → 0, VREF_MV → 65535
    return UInt32(round(clamp(val, 0, VREF_MV) / VREF_MV * 65535))
end

function test_dac_poll(gate::portal_gate_t)
    portal = Portal_Wormhole(BACKEND_USB, gate)
    dac = DAC_PMOD_CTRL(portal)
    try
        # Write a single sample to the poll register
        sample_value = from_mV(2500.0)  # Full-scale Vref mV
        println("Writing poll sample value: $sample_value")
        poll_write(dac, [sample_value])

        # Read back the current sample value using read_word
        #read_value = read_word(dac, UInt32(dac_pmod_ctrl_cfg.POLL_SMPL_ADDR))
        #println("Read back poll sample value: $read_value")

        #if read_value == sample_value
        #    println("Poll register readback OK")
        #else
        #    println("Poll register readback FAILED: expected $sample_value, got $read_value")
        #end

    catch e
        println("Error: $e")
        rethrow(e)
    finally
        close(dac.portal)
    end
end

# Continuous sine output for scope debugging — Ctrl+C to stop
function scope_debug_sine(gate::portal_gate_t, n::Int = 512)
    portal  = Portal_Wormhole(BACKEND_USB, gate)
    dac     = DAC_PMOD_CTRL(portal)

    # Pre-generate sine samples
    half    = (1 << 15) - 0.5
    samples = [UInt32(round(half + half * sin(2π * (i-1) / n))) for i in 1:n]

    println("Streaming sine to DAC — Ctrl+C to stop")
    try
        while true
            for s in samples
                poll_write(dac, [s])
            end
        end
    catch e
        e isa InterruptException || println("Error: $e")
    finally
        poll_write(dac, [UInt32(0x7FFF)])  # leave at midpoint
        close(dac.portal)
        println("Stopped.")
    end
end


# N = 256  # 1 iter
 N = 1 << 10  # 2 iters

    #scope_debug_sine(PG_DAC_PMOD_0)
    sleep(1)

    println("Testing DAC PMOD 0 (sine) with N=$N samples")
    #test_dac_sine(PG_DAC_PMOD_0, N)
    sleep(1)

    println("Testing DAC PMOD 0 buffer readback with N=$N samples")
    test_dac_buf_readback(PG_DAC_PMOD_0, N)
    sleep(1)
if false

    #("Testing DAC PMOD 0 buffer readback with N=$N samples")
    #test_dac_buf_readback(PG_DAC_PMOD_0, N)
    #sleep(1)


    #println("Testing DAC PMOD 0 poll")
    #test_dac_poll(PG_DAC_PMOD_0)
end
println("End")
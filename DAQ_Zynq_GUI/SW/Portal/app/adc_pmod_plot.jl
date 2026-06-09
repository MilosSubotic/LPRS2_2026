#!/usr/bin/env julia

include("../Portal_inc.jl")

using Plots
gr()  # No Python dependency. Swap to pyplot() if you prefer matplotlib style.

# ── Config ────────────────────────────────────────────────────────────────────

const GATE       = PG_ADC_PMOD_0   # Change to PG_ADC_PMOD_1 if needed
const N          = 1 << 12       # Number of samples
const VREF       = 3.3            # Reference voltage (V)
const BITS       = 12              # ADC resolution
const F_SMPL     = 270_270      # Sample rate in Hz — adjust to your actual rate
const LIVE_LOOP  = true           # true = repeated capture loop, false = single shot

# ── Helpers ───────────────────────────────────────────────────────────────────

adc_to_mv(sample::Integer) = sample * VREF * 1000 / ((1 << BITS) - 1)

t_axis(n) = collect(0:n-1) ./ F_SMPL .* 1000  # Time axis in ms

# ── Single capture ────────────────────────────────────────────────────────────

function capture(gate::portal_gate_t, ch::Int, n::Int)
    portal = Portal_Wormhole(BACKEND_USB, gate)
    adc    = ADC_PMOD_CTRL(portal)
    samples = zeros(UInt32, n)
    try
        cnv_trig(adc, ch, n)
        while true
            sleep(0.1)
            progress = cnv_progress(adc)
            println("Progress: $progress%")
            progress == 100 && break
        end
        read_buf!(adc, ch, samples)
    catch e
        println("Capture error: $e")
    finally
        close(adc.portal)
    end
    return samples
end

# ── Plot one capture ──────────────────────────────────────────────────────────

function plot_samples(samples::Vector{UInt32}; title_str = "ADC PMOD capture")
    mv = adc_to_mv.(samples)
    t  = t_axis(length(samples))

    println("Min: $(round(minimum(mv), digits=2)) mV   Max: $(round(maximum(mv), digits=2)) mV")

    pl = plot(
        t, mv,
        title  = title_str,
        xlabel = "Time [ms]",
        ylabel = "Voltage [mV]",
        label  = "Signal",
        lw     = 1.5,
        marker = (:circle, 3),
        legend = :topright,
        size   = (1200, 800),
    )
    gui(pl)
    return pl
end

# ── Main ──────────────────────────────────────────────────────────────────────

closeall()
default(reuse = false)
ch= 1
if LIVE_LOOP
    println("Starting live capture loop. Ctrl+C to stop.")
    default(reuse = true)
    local iter = 1                       # explicit local — fixes scope warning
    while true
        println("\n─── Iteration $iter ───")
        local samples = capture(GATE, ch, N) # explicit local — fixes scope warning
        plot_samples(samples; title_str = "ADC PMOD — iter $iter")
        iter += 1
        sleep(0.5)
    end
else
    println("Capturing $N samples from $GATE...")
    samples = capture(GATE, ch, N)
    plot_samples(samples)
    println("Done. Press Enter to exit.")
    readline()
end
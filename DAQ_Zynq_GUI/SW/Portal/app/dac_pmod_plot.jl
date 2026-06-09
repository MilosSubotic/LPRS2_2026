#!/usr/bin/env julia

include("../Portal_inc.jl")

using Plots
gr()

##############################################

# ── Config ────────────────────────────────────────────────────────────────────

const GATE      = PG_DAC_PMOD_0
const N         = 1 << 14
const PERIODS   = 1
const VREF_MV   = 2500.0           # AD5541 Vref in mV — measure your actual Vref pin
const BITS      = 16
const F_SMPL    = 270_270      # Hz — adjust to your actual DAC sample rate

# ── Waveform selection ────────────────────────────────────────────────────────

const WAVE_RAMP      = false
const WAVE_SINE      = false
const WAVE_DC        = false
const WAVE_TRIANGLE  = false
const WAVE_SQUARE    = false
const WAVE_TRAPEZOID = false
const WAVE_STAIRCASE = false
const WAVE_BURST     = false
const WAVE_EXP       = false    
const WAVE_SPEC      = false
const WAVE_SEQ       = true
const DC_MV      = 1250.0

# ── Helpers ───────────────────────────────────────────────────────────────────

dac_to_mv(code::Integer)   = code / ((1 << BITS) - 1) * VREF_MV
mv_to_dac(mv::Real)::UInt32 = UInt32(round(clamp(mv, 0, VREF_MV) / VREF_MV * ((1 << BITS) - 1)))
t_axis(n) = collect(0:n-1) ./ F_SMPL .* 1e6   # µs

# ── Waveform generators ───────────────────────────────────────────────────────

function gen_ramp(n)
    [UInt32((i - 1) * ((1 << BITS) - 1) ÷ (n - 1)) for i in 1:n]
end

function gen_sine(n::Int, periods::Int = 1, Vpp::Float64 = VREF_MV, Vcenter::Float64 = VREF_MV/2.0)
    amp_mv   = clamp(Vpp / 2.0, 0.0, VREF_MV / 2.0)
    amp_code = amp_mv / VREF_MV * ((1 << BITS) - 1)
    mid_code = mv_to_dac(clamp(Vcenter, 0.0, VREF_MV))  # absolute center, clamped

    [UInt32(round(mid_code + amp_code * sin(2π * periods * (i-1) / n))) for i in 1:n]
end

function gen_dc(n, mv)
    fill(mv_to_dac(mv), n)
end

# ── Custom waveform generators ────────────────────────────────────────────────

function gen_triangle(n::Int, periods::Int = 1)
    # Linear ramp up then down
    period_len = n ÷ periods
    samples = zeros(UInt32, n)
    for i in 1:n
        t = ((i - 1) % period_len) / period_len  # 0..1 within period
        val = t < 0.5 ? 2t : 2(1 - t)            # triangle shape 0..1..0
        samples[i] = UInt32(round(val * ((1 << BITS) - 1)))
    end
    samples
end

function gen_square(n::Int, periods::Int = 1, duty::Float64 = 0.5, Vmin::Float64 = 0.0 , Vmax::Float64 = VREF_MV)
    # Duty cycle 0.0..1.0
    period_len = n ÷ periods
    samples = zeros(UInt32, n)
    high = mv_to_dac(Vmax)
    for i in 1:n
        t = ((i - 1) % period_len) / period_len
        samples[i] = t < duty ? high : mv_to_dac(Vmin)
    end
    samples
end

function gen_trapezoid(n::Int, periods::Int = 1,
                        rise::Float64 = 0.1, high::Float64 = 0.4,
                        fall::Float64 = 0.1)
    # rise, high, fall, low as fractions of period (must sum <= 1.0)
    # low = remaining fraction
    period_len = n ÷ periods
    max_val = Float64((1 << BITS) - 1)
    samples = zeros(UInt32, n)
    for i in 1:n
        t = ((i - 1) % period_len) / period_len
        val = if t < rise
            t / rise                          # rising edge
        elseif t < rise + high
            1.0                               # high plateau
        elseif t < rise + high + fall
            1.0 - (t - rise - high) / fall    # falling edge
        else
            0.0                               # low plateau
        end
        samples[i] = UInt32(round(val * max_val))
    end
    samples
end


function gen_staircase(n::Int, periods::Int = 1, steps::Int = 8)
    # Ascending staircase with configurable number of steps
    period_len = n ÷ periods
    max_val = (1 << BITS) - 1
    samples = zeros(UInt32, n)
    for i in 1:n
        t = ((i - 1) % period_len) / period_len
        step = floor(Int, t * steps)
        samples[i] = UInt32(round(step / (steps - 1) * max_val))
    end
    samples
end


function gen_exponential(n::Int, periods::Int = 1, decay::Float64 = 5.0)
    # Exponential decay per period, restarts each period
    period_len = n ÷ periods
    max_val = Float64((1 << BITS) - 1)
    samples = zeros(UInt32, n)
    for i in 1:n
        t = ((i - 1) % period_len) / period_len
        val = exp(-decay * t)
        samples[i] = UInt32(round(val * max_val))
    end
    samples
end

function gen_special(n::Int, periods::Int = 1, duty::Float64 = 0.5,
                     Vlow::Float64 = 0.0, Vhigh::Float64 = VREF_MV,
                     Vsinpp::Float64 = VREF_MV)

    period_len = n ÷ periods
    n_high     = round(Int, period_len * duty)   # samples in HIGH half of ONE period
    n_low      = period_len - n_high             # samples in LOW half of ONE period

    # Generate ONE period's worth of high and low
    high = gen_sine(n_high, 1, Vsinpp, Vhigh)
    low  = gen_sine(n_low,  1, Vsinpp, Vlow)

    samples = zeros(UInt32, n)
    for i in 1:n
        local_i = ((i - 1) % period_len)        # 0-based position within period
        if local_i < n_high
            samples[i] = high[local_i + 1]
        else
            samples[i] = low[local_i - n_high + 1]
        end
    end
    samples
end

function gen_pump_sequence(;
    Vlow_mv::Float64     = 500.0,
    Vhigh_mv::Float64    = 1500.0,
    Vrest_mv::Float64    = 1000.0,
    Vsinpp_mv::Float64   = 100.0,
    F_smpl::Float64      = Float64(F_SMPL),
    t_pump_ms::Float64   = 30.0,
    t_rest_ms::Float64   = 70.0,
    f_square_hz::Float64 = 1000.0,
    pkg_size::Int        = 128)

    # ── Pump: snap to exact periods ──────────────────────────────────
    periods    = round(Int, f_square_hz * t_pump_ms / 1000.0)
    n_pump_raw = round(Int, t_pump_ms / 1000.0 * F_smpl)
    period_len = n_pump_raw ÷ periods
    n_pump     = period_len * periods

    # ── Rest: raw count ───────────────────────────────────────────────
    n_rest = round(Int, t_rest_ms / 1000.0 * F_smpl)

    # ── Snap TOTAL to pkg_size boundary by adjusting rest ────────────
    n_total_raw = n_pump + n_rest
    n_total     = ((n_total_raw + pkg_size - 1) ÷ pkg_size) * pkg_size
    n_rest      = n_total - n_pump

    println("Sequence breakdown:")
    println("  pump : $n_pump samples  ($(round(n_pump/F_smpl*1000, digits=2)) ms)")
    println("  rest : $n_rest samples  ($(round(n_rest/F_smpl*1000, digits=2)) ms)")
    println("  total: $n_total samples → $(n_total ÷ pkg_size) full BDs ✓")
    @assert n_total % pkg_size == 0 "BUG: total still not divisible!"

    pump = gen_special(n_pump, periods, 0.5, Vlow_mv, Vhigh_mv, Vsinpp_mv)
    rest = gen_dc(n_rest, Vrest_mv)

    seq = vcat(pump, rest)
    @assert length(seq) == n_total "BUG: length mismatch!"
    return seq
end

function build_waveform(n::Int, p::Int, Vmin::Float64 = 0.0 , Vmax::Float64 = VREF_MV, Vsinpp::Float64 = VREF_MV)
    WAVE_RAMP      && return gen_ramp(n),                    "Ramp"
    WAVE_SINE      && return gen_sine(n, p),                 "Sine"
    WAVE_DC        && return gen_dc(n, DC_MV),               "DC $(DC_MV) mV"
    WAVE_TRIANGLE  && return gen_triangle(n, p),             "Triangle"
    WAVE_SQUARE    && return gen_square(n, p, 0.5, Vmin, Vmax),          "Square 50%"
    WAVE_TRAPEZOID && return gen_trapezoid(n, p),            "Trapezoid"
    WAVE_STAIRCASE && return gen_staircase(n, p, 8),         "Staircase 8-step"
    WAVE_EXP       && return gen_exponential(n, p, 5.0),     "Exponential Decay"
    WAVE_SPEC      && return gen_special(n, p, 0.5, Vmin, Vmax, Vsinpp), "Special signal"
    WAVE_SEQ       && return gen_pump_sequence(
        Vlow_mv   = 500.0,
        Vhigh_mv  = 1500.0,
        Vrest_mv  = 1000.0,
        Vsinpp_mv = 100.0
    ), "Pump sequence"
    error("No waveform selected")
end

# ── Send to DAC ───────────────────────────────────────────────────────────────

function send_to_dac(dac::DAC_PMOD_CTRL, samples::Vector{UInt32})
   
    #try
        if (dma_write_done(dac) == 1)
            println("Writing $(length(samples)) samples...")
            write_buf(dac, samples)
            
            cpu_write_done(dac)
        else
            println("Waiting for DMA...")
        end
        
        println("Triggering DAC...")
        cnv_trig(dac, length(samples))
        while true
            sleep(0.1)
            progress = cnv_progress(dac)
            println("Progress: $progress%")
            progress >= 100 && break
        end
        println("DAC playback complete.")
end

# ── Scope-style plot ──────────────────────────────────────────────────────────

function plot_waveform(samples::Vector{UInt32}; title_str = "DAC PMOD")
    mv = dac_to_mv.(samples)
    t  = t_axis(length(samples))

    period_us = N / F_SMPL / PERIODS * 1e6
    freq_hz   = PERIODS * F_SMPL / N

    println("Waveform stats:")
    println("  Min   : $(round(minimum(mv), digits=2)) mV")
    println("  Max   : $(round(maximum(mv), digits=2)) mV")
    println("  Period: $(round(period_us, digits=2)) µs")
    println("  Freq  : $(round(freq_hz, digits=2)) Hz")

    theme(:default)

    pl = plot(
        size                     = (1200, 600),
        background_color         = :white,
        background_color_subplot = :white,
        foreground_color         = :black,
    )

    plot!(pl,
        t, mv,
        title      = "$(title_str)  |  $(round(freq_hz, digits=1)) Hz  |  Vref=$(VREF_MV) mV",
        xlabel     = "Time [µs]",
        ylabel     = "Voltage [mV]",
        label      = "DAC out (mV)",
        lw         = 2,
        color      = :blue,
        marker     = (:circle, 3, :blue),
        legend     = :topright,
        ylims      = (-VREF_MV * 0.05, VREF_MV * 1.1),
        grid       = true,
        gridcolor  = RGB(0.8, 0.8, 0.8),
        gridstyle  = :dot,
        minorgrid  = true,
    )

    hline!(pl, [0.0],       label = "0 V",    color = :red,    lw = 1, ls = :dash)
    hline!(pl, [VREF_MV/2], label = "Vref/2", color = :gray,   lw = 1, ls = :dash)
    hline!(pl, [VREF_MV],   label = "Vref",   color = :green,  lw = 1, ls = :dash)

    gui(pl)
    return pl
end


# ── Main ──────────────────────────────────────────────────────────────────────

closeall()
default(reuse = false)
Vmin = 0.5
Vmax = 1.5
Vsinpp = 0.1
samples, wave_label = build_waveform(N, PERIODS, Vmin *1000, Vmax*1000, Vsinpp*1000)

println("Waveform : $wave_label")
println("Samples  : $N  |  Rate: $(F_SMPL) Hz  |  VREF: $(VREF_MV) mV")

plot_waveform(samples; title_str = "DAC PMOD — $wave_label")

print("\nSend to DAC? (y/n): ")
if readline() == "y"
    portal = Portal_Wormhole(BACKEND_USB, GATE)
    dac    = DAC_PMOD_CTRL(portal)
    try
        while true
            send_to_dac(dac, samples)
            sleep(0.001)   # 10ms gap between bursts
        end
    catch e
        if isa(e, InterruptException)
            println("\nStopping DAC...")
            cnv_stop(dac)
            println("DAC stopped.")
        else
            rethrow(e)
        end
    finally
        close(dac.portal)
    end
end

println("Done. Press Enter to exit.")
readline()
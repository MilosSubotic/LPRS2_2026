


export 
	Portal_Wormhole,
	close,
	BACKEND_USB,
	BACKEND_LAN

PORTAL_MAX_PAYLOAD_SIZE = 256


import Pkg
for pkg in ["Plots", "GR", "GLMakie"]
    if !haskey(Pkg.project().dependencies, pkg)
        Pkg.add(pkg)
    end
end

include("../../Common/SW/Utils.jl")
using .Utils
include("../../Common/SW/Units.jl")
using .Units
push!(LOAD_PATH, "../../Common/SW/")
#using .Utils


import Base: close

include("backends/USB.jl")

@enum portal_backend_t BACKEND_USB BACKEND_LAN

include("priv/portal_gate.jl")

include("priv/wormhole.jl")

#include("priv/SV_CPU.jl")
#include("priv/ADC_DMA.jl")
include("priv/DAC_Jmp.jl")
#include("priv/ADC_Pmod_Poll.jl")
include("priv/ADC_Pmod_Ctrl.jl")
include("priv/DAC_Pmod_Ctrl.jl")



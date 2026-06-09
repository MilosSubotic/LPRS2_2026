

mutable struct Portal_Wormhole
	backend
	gate
end
PORTAL_ADDR_BITS = 32 - ceil(Int, log2(length(instances(portal_gate_t))))

function Portal_Wormhole(bt::portal_backend_t, gate::portal_gate_t )
	if bt == BACKEND_USB
		backend = USB()
	elseif bt == BACKEND_LAN
		throw(LoadError("Not implemented!"))
	end
	p = Portal_Wormhole(backend, gate)

	if false
		#FIXME
		finalizer(
			function(p::Portal_Wormhole)
				println("finilizing Portal_Wormhole...")
				close(p)
			end,
			p
		)
	end

	return p
end

function write(p::Portal_Wormhole, addr::UInt32, data::Array)
	@assert addr < 1<<PORTAL_ADDR_BITS

	size = sizeof(data)
	for i in 1:PORTAL_MAX_PAYLOAD_SIZE:size
		chunk_beg = i
		chunk_end = min(i+PORTAL_MAX_PAYLOAD_SIZE-1, size)
		chunk_size = chunk_end-chunk_beg+1
		chunk_addr = addr + chunk_beg-1

		header = UInt64(p.gate) << PORTAL_ADDR_BITS | UInt64(chunk_addr) | UInt64(chunk_size) << 32 | UInt64(1)<<63

		header_p = convert(Ptr{UInt8}, pointer([header]))

		buf = vcat(
			reinterpret(UInt8, [header]),
			reinterpret(UInt8, data)[chunk_beg:chunk_end]
		)

		buf_p = convert(Ptr{UInt8}, pointer(buf))

		write(p.backend, sizeof(buf), buf_p)
	end

end


function read!(p::Portal_Wormhole, addr::UInt32, data::Array)
	@assert addr < 1<<PORTAL_ADDR_BITS

	size = sizeof(data)
	for i in 1:PORTAL_MAX_PAYLOAD_SIZE:size
		chunk_beg = i
		chunk_end = min(i+PORTAL_MAX_PAYLOAD_SIZE-1, size)
		chunk_size = chunk_end-chunk_beg+1
		chunk_addr = addr + chunk_beg-1

		chunk_beg_e = div(chunk_beg-1, sizeof(eltype(data)))+1
		chunk_p = convert(Ptr{UInt8}, pointer(data, chunk_beg_e))

		header = UInt64(p.gate) << PORTAL_ADDR_BITS | UInt64(chunk_addr) | UInt64(chunk_size) << 32 | UInt64(0)<<63

		header_p = convert(Ptr{UInt8}, pointer([header]))
		write(p.backend, sizeof(header), header_p)

		read!(p.backend, chunk_size, chunk_p)
	end
end

function close(p::Portal_Wormhole)
	#println("Closing Portal_Wormhole...")
	close(p.backend)
end


USB_VENDOR_ID = 0x03FD
USB_PRODUCT_ID = 0x0000
USB_INTERFACE = 0
USB_ENDPOINT = 1
USB_TIMEOUT = 1000 # [ms]

install_if_not_installed(["libusb_jll"])

using libusb_jll

LIBUSB_ENDPOINT_IN  = 0x80
LIBUSB_ENDPOINT_OUT = 0x00
LIBUSB_ERROR_TIMEOUT = -7

# host-to-device.
ENDPOINT_TX = LIBUSB_ENDPOINT_OUT | USB_ENDPOINT
# device-to-host.
ENDPOINT_RX = LIBUSB_ENDPOINT_IN | USB_ENDPOINT

mutable struct USB
	ctx::Ptr{Cvoid}
	handle::Ptr{Cvoid}
end


function USB()
	usb = USB(
		Ptr{Cvoid}(),
		C_NULL
	)

	r = ccall(
		(:libusb_init, libusb),
		Cint,
		(Ptr{Ptr{Cvoid}},),
		Ref(usb.ctx)
	)
	if r != 0
		throw("libusb_init() failed with $(r)!")
	end

	usb.handle = ccall(
		(:libusb_open_device_with_vid_pid, libusb),
		Ptr{Cvoid},
		(Ptr{Cvoid}, UInt16, UInt16),
		usb.ctx,
		USB_VENDOR_ID,
		USB_PRODUCT_ID
	)
	if usb.handle == C_NULL
		@ccall perror("Device not found"::Cstring)::Cvoid
		throw("libusb_open_device_with_vid_pid(): failed!")
	end

	r = ccall(
		(:libusb_claim_interface, libusb),
		Cint,
		(Ptr{Cvoid}, Cint),
		usb.handle,
		USB_INTERFACE
	)
	if r < 0
		throw("libusb_claim_interface(): failed with $(r)!")
	end

	if false
		#FIXME
		finalizer(
			function(usb::USB)
				println("finilizing USB...")
				close(usb)
			end,
			usb
		)
	end

	return usb
end


function _bulk_transfer(usb, size, ptr, enpoint_tx_rx)

	transfered = Cint[0]
	r = ccall(
		(:libusb_bulk_transfer, libusb),
		Cint,
		(Ptr{Cvoid}, Cuchar, Ptr{Cuchar}, Cint, Ptr{Cint}, Cuint),
		usb.handle,
		enpoint_tx_rx,
		ptr, # data
		UInt32(size), # length
		transfered,
		USB_TIMEOUT
	)
	if r != 0
		if r == LIBUSB_ERROR_TIMEOUT
			r2 = "Timeout"
		else
			r2 = ""
		end
		throw("libusb_bulk_transfer(): failed with $(r) $(r2)!")
	else
		if transfered[1] != size
			#throw("libusb_bulk_transfer(): Not all transfered!")
		end
	end
end

function write(usb::USB, size, ptr::Ptr{UInt8})
	@assert size <= 8+PORTAL_MAX_PAYLOAD_SIZE
	_bulk_transfer(usb, size, ptr, ENDPOINT_TX)
end

function read!(usb::USB, size, ptr::Ptr{UInt8})
	@assert size <= PORTAL_MAX_PAYLOAD_SIZE
	_bulk_transfer(usb, size, ptr, ENDPOINT_RX)
end

function close(usb::USB)
	# Guard against double-close
    if usb.handle == C_NULL
        return
    end
	println("Closing USB...")

	ccall(
		(:libusb_close, libusb),
		Cvoid,
		(Ptr{Cvoid},),
		usb.handle
	)
	usb.handle = C_NULL
	ccall(
		(:libusb_exit, libusb),
		Cvoid,
		(Ptr{Cvoid},),
		usb.ctx
	)
	usb.ctx = C_NULL
end


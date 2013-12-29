#= services integration
module ServicesHandler
	# NOTE the respondsToSelector borking can happen with this method. need to find out why.
	def handle_service(pasteboard_data, userData:data, error:err)
		pe_warn "Service invoked: #{pasteboard_data}, #{data}"
		
		@service_data = pasteboard_data
		
		# interpret the pasteboard and act accordingly.
		string = pasteboard_data.stringForType(NSPasteboardTypeString)  # must get the type right.
		
		pe_log "service handler received: '#{string}'"
		NSApp.delegate.wc
			.do_activate
			.component(InputHandler).process_input string
	end
end

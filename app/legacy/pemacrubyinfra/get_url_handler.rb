module GetUrlHandler

	#= url scheme handling

	def register_url_handling
		result = LSRegisterURL(NSBundle.mainBundle.bundleURL, true)
		pe_warn "result code from LSRegisterURL: #{result}"
		
		NSAppleEventManager.sharedAppleEventManager.setEventHandler(self, andSelector: 'getUrl:withReplyEvent:', forEventClass:KInternetEventClass, andEventID:KAEGetURL)
	end

	def getUrl(url_event, withReplyEvent:reply_event)
		details = { url_event: url_event, url:url_event.url_string, reply_event:reply_event }
		pe_warn "getUrl: #{details}"

		self.on_get_url( details )
		# TODO replace with user.perform_url_invocation
	end

end
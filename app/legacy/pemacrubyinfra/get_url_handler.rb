module GetUrlHandler

	attr_accessor :requested_url
	
	#= url scheme handling

	def register_url_handling
		result = LSRegisterURL(NSBundle.mainBundle.bundleURL, true)
		pe_warn "result code from LSRegisterURL: #{result}"
		
		NSAppleEventManager.sharedAppleEventManager.setEventHandler(self, andSelector: 'getUrl:withReplyEvent:', forEventClass:KInternetEventClass, andEventID:KAEGetURL)
	end

	def getUrl(url_event, withReplyEvent:reply_event)
		url = url_event.url_string
		details = { url_event: url_event, url:url, reply_event:reply_event }
		pe_warn "getUrl: #{details}"

		self.requested_url = url

		# WORKAROUND kvo swizzling resulting in nil
		component = self.component BrowserDispatch
		if component
			component.on_get_url details
		else 
			pe_warn "component not initialised. not dispatching requested_url"
		end
	end

end
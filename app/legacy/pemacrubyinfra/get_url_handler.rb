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
		push_work = -> {
			dispatcher = component(BrowserDispatch)
			if dispatcher
				on_main_async do
					dispatcher.on_get_url details
				end
			else
				pe_log "no BrowserDispatch component initialised. requeueing..."

				# keep queueing until it's done.
				on_main_async do
					push_work.call
				end
			end
		}
		on_main_async do
			push_work.call
		end
	end

	#==

	module InstanceMethods
		def applicationWillFinishLaunching(notification)
			# this must be done early in order to catch gurl events on launch.
			register_url_handling
		end
	end
	
	def self.included(receiver)
		receiver.send :include, InstanceMethods
	end
end

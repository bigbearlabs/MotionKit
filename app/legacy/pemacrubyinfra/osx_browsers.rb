module Browsers
	Browsers_by_name = {
		WebBuddy: {
			bundle_id: "com.bigbearlabs.WebBuddy",
			description: "" # default to entry name.
		},
		Safari: {
			bundle_id: "com.apple.Safari",
		},
	  Chrome: {
	  	bundle_id: "com.google.Chrome"
		},
	  Firefox: {
	  	bundle_id: "org.mozilla.firefox"
	  },
	  Opera: {
	  	bundle_id: "com.operasoftware.Opera"
		},
	  safari_this_space: {
	  	bundle_id: "com.bigbearlabs.SafariOnThisSpace"
		},
	  chrome_this_space: {
	  	bundle_id: "com.bigbearlabs.ChromeOnThisSpace"
	  }
	}

	def self.default_browser
		# MOTION-MIGRATION
		# default_browser_bid = LSCopyDefaultHandlerForURLScheme("http")
		# default_browser_bid

		'com.bigbearlabs.WebBuddy'
	end

	# FIXME when bundle id resolves to multiple apps, we can have weird issues here.
	def self.set_default_browser( bundle_id )
		# MOTION-MIGRATION
		# ret1 = LSSetDefaultHandlerForURLScheme("http",  bundle_id)
		# ret2 = LSSetDefaultHandlerForURLScheme("https", bundle_id)
		# ret3 = LSSetDefaultHandlerForURLScheme("file", bundle_id) # EDGECASE folders
		# if (ret1 == 0 && ret2 == 0 && ret3 == 0)
		# 	pe_warn "set default browser to #{bundle_id}"
		# else
		# 	raise "return codes #{ret1}, #{ret2}, #{ret3} setting default browser to #{bundle_id}"
		# 	# TODO user-friendly dialog for the error.
		# end
	end

	# return hash of details bundle_id, description keyed by name
	def self.installed_browsers
		handlers = LSCopyAllHandlersForURLScheme('http')
		handlers.inject({}) do |acc, handler_bundle_id|
			begin
				bundle_path = NSWorkspace.sharedWorkspace.absolutePathForAppBundleWithIdentifier(handler_bundle_id)

				if bundle_path
					app_name = File.basename(bundle_path).to_s.gsub(/\.app$/, '')
					icon = NSWorkspace.sharedWorkspace.iconForFile(bundle_path)

					browser_spec = {
						bundle_id: handler_bundle_id,
						description: app_name,
						icon: icon
					}

					pe_debug "create a browser definition for #{browser_spec}"
					acc[app_name.intern] = browser_spec
				else
					pe_warn "bundle_path for #{handler_bundle_id} is nil; skipping."
				end
			rescue Exception => e
				pe_report e, "for browser '#{handler_bundle_id}"
			end
			
			acc
		end
	end

	def self.open_url( url, bundle_id )
    NSWorkspace.sharedWorkspace.openURLs( [ url.to_url ], withAppBundleIdentifier:bundle_id, options:NSWorkspaceLaunchDefault, additionalEventParamDescriptor:nil, launchIdentifiers:nil )
	end
end
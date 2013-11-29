def watch_workspace_notification( notification_name, sender = nil )
	watch_notification notification_name, sender, NSWorkspace.sharedWorkspace.notificationCenter
end

# registers self to observe notification of name notification_name, and handle using the block if given, or a method on receiver with the signature 'handle_<notification_name>( notification )'.
def watch_notification( notification_name, sender = nil, notification_center = NSNotificationCenter.defaultCenter )

	selector_name = "handle_#{notification_name}:"

	if block_given?

		# define a wrapper method that yields
		self.def_method_once selector_name do |notification|
			yield notification
		end

	elsif ! self.respond_to? selector_name
		
		self.def_method_once selector_name do |notification|
			# define a handle_* that sends to an on_*, working around compile-time wiring to selector implementation (breaking hotload)
			on_method = "on_#{notification_name}:"
			if self.respond_to? on_method
				self.send on_method, notification
			else
				# define the logging handler
				pe_log "#{notification_name} received with #{notification.description}"
			end
		end

	end

	notification_center.addObserver(self, selector:selector_name, name:notification_name, object:sender)
		
	pe_log "#{self} registered for notification: #{notification_name} from sender #{sender}"

	self
end

# TODO deregistration

# TODO post
def send_notification( notification_name, object = nil, sender = self )
  pe_debug "sending notification #{notification_name}, object:#{object}, from #{caller[1]}"

	notification = NSNotification.notificationWithName(notification_name, object:sender, userInfo:object)
	NSNotificationCenter.defaultCenter.postNotification(notification)
end

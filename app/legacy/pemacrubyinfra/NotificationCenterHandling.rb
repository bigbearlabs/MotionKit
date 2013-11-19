#
#  NotificationCenterHandling.rb
#  WebBuddy
#
#  Created by Park Andy on 07/04/2012.
#  Copyright 2012 __MyCompanyName__. All rights reserved.
#


# registers self to observe notification of name notification_name, and handle using the block if given, or a method on receiver with the signature 'handle_<notification_name>( notification )'.
# FIXME blows up if the handle_method not defined
def observe_notification( notification_name, sender = nil )
	watch_notification notification_name, sender
end

def watch_workspace_notification( notification_name, sender = nil )
	watch_notification notification_name, sender, NSWorkspace.sharedWorkspace.notificationCenter
end

def watch_notification( notification_name, sender = nil, notification_center = NSNotificationCenter.defaultCenter )

	selector_name = "handle_#{notification_name}:"

	if block_given?

		# define a wrapper method that yields
		self.def_method_once selector_name do |notification|
			yield notification
		end

	elsif ! self.respond_to? selector_name
		
		# define the logging handler
		self.def_method_once selector_name do |notification|
			on_method = "on_#{notification_name}:"
			if self.respond_to? on_method
				self.send on_method, notification
			else
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

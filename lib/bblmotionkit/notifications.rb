# FIXME calculate the increment based on logic similar to https://github.com/csheldrick/UILocalNotification

module Notifications

  def notify_in( time_interval = 10, message = 'Alert', owner = self)
    since = Time.now

    application = UIApplication.sharedApplication

    notification = UILocalNotification.alloc.init
    notification.userInfo = { "owner" => 'owner' }
    notification.fireDate = NSDate.dateWithTimeIntervalSinceNow(time_interval)
    notification.alertBody = message
    notification.alertAction = "View Timer"
    notification.applicationIconBadgeNumber = [badge_number, 0].max + 1
    # TODO dismiss button label

    application.scheduleLocalNotification(notification)

    pe_debug "scheduled #{notification.inspect}"
    notification
  end

  def cancel_notification( notification )
     UIApplication.sharedApplication.cancelLocalNotification(notification)
    pe_debug "cancelled #{notification.inspect}"
  end

  def dismiss_notification( notification )
    cancel_notification notification

    if notification.fireDate.is_past
      pe_debug "dismissing #{notification}."

      self.badge_number = badge_number - 1
    end
  end

  def notifications_for owner
    app.scheduledLocalNotifications.select do |notif|
      notif.userInfo && notif.userInfo["owner"] == 'owner'
    end
  end
  
  #=

  def badge_number
    app.applicationIconBadgeNumber
  end
  
  def badge_number= number
    app.applicationIconBadgeNumber = number
  end
  
end


class NSDate
  def is_past
    self.compare(NSDate.date) == NSOrderedAscending
  end
end
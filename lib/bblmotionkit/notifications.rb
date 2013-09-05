# FIXME calculate the increment based on logic similar to https://github.com/csheldrick/UILocalNotification

module Notifications

  def notify_in( time_interval = 10, message = 'Notification', badge_count = nil, owner = self)
    since = Time.now

    application = UIApplication.sharedApplication

    notification = UILocalNotification.alloc.init
    notification.userInfo = { "owner" => owner.to_s }
    notification.fireDate = NSDate.dateWithTimeIntervalSinceNow(time_interval)
    notification.alertBody = message
    notification.alertAction = "View Timer"
    notification.applicationIconBadgeNumber = badge_count if badge_count

    # TODO set dismiss button message.

    application.scheduleLocalNotification(notification)

    pe_log "scheduled #{notification} with badge_count #{badge_count}, owner #{owner.to_s}" 

    notification
  end

  def cancel_notification( notification )
    UIApplication.sharedApplication.cancelLocalNotification(notification)

    pe_log "cancelled #{notification}"
  end

  def dismiss_notification( notification )
    cancel_notification notification

    if notification.fireDate.is_past
      pe_log "dismissing #{notification}."

      self.badge_count = badge_count - 1
    end
  end

  def notifications_for owner
    app.scheduledLocalNotifications.select do |notif|
      notif.userInfo && notif.userInfo["owner"] == owner.to_s
    end
  end
  
  #=

  def badge_count
    app.applicationIconBadgeNumber
  end
  
  def badge_count= number
    app.applicationIconBadgeNumber = number
  end
  
end


class NSDate
  def is_past
    self.compare(NSDate.date) == NSOrderedAscending
  end
end


class UILocalNotification
  # NOTE disabled due to annoyingly weird crashes involving plist and CFNull type.
  # def to_s
  #   self.inspect
  # end
end

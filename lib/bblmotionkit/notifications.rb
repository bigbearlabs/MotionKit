module Notifications
  def notify_in( time_interval = 10, since = Time.now)
    application = UIApplication.sharedApplication

    notification = UILocalNotification.alloc.init
    notification.fireDate = NSDate.dateWithTimeIntervalSinceNow(time_interval)
    notification.alertBody = "My first notification"
    notification.alertAction = "OneHour"
    notification.applicationIconBadgeNumber = 1
    # TODO dismiss button label
    application.scheduleLocalNotification(notification)

    notification
  end

  def cancel_notification( notification )
     UIApplication.sharedApplication.cancelLocalNotification(notification)
  end
end
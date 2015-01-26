# FIXME calculate the increment based on logic similar to https://github.com/csheldrick/UILocalNotification

module Notifications

  def register_platform_notifications
    # platform: ios
    # FIXME stuff specific to OneHour -- push down.
    categories = [
      UIMutableUserNotificationCategory.new.tap do |category|

        category.identifier = "time_up"
        
        actions_minimal = [
          UIMutableUserNotificationAction.new.tap do |action|
            action.identifier = "review"
            action.title = action.identifier.capitalize
            action.activationMode = UIUserNotificationActivationModeForeground
            # action.destructive = 
          end,
        
          UIMutableUserNotificationAction.new.tap do |action|
            action.identifier = "dismiss"
            action.title = action.identifier.capitalize
            action.activationMode = UIUserNotificationActivationModeBackground
          end,
        ]

        actions_other = [
          UIMutableUserNotificationAction.new.tap do |action|
            action.identifier = "dismiss"
            action.title = action.identifier.capitalize
            action.activationMode = UIUserNotificationActivationModeBackground
          end,

          # UIMutableUserNotificationAction.new.tap do |action|
          #   action.identifier = "snooze_5"
          #   action.title = action.identifier.capitalize
          #   action.activationMode = UIUserNotificationActivationModeBackground
          # end,
        ]

        category.setActions(actions_minimal, forContext:UIUserNotificationActionContextMinimal)
        category.setActions(actions_other, forContext:UIUserNotificationActionContextDefault)
      end
    ]

    app.registerUserNotificationSettings(UIUserNotificationSettings.settingsForTypes(UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound, categories:NSSet.setWithArray(categories)))

    pe_log "registered for platform notifications"
  end
  
  def notify_in( time_interval = 10, opts)
    message = opts[:message] || 'Notification'
    sound = opts[:sound] || UILocalNotificationDefaultSoundName
    owner = opts[:owner] || self

    repeat = 
      case opts[:repeat]
      when :second
        NSSecondCalendarUnit
      else
        NSMinuteCalendarUnit
      end

    badge_count = opts[:badge_count]

    notification = UILocalNotification.alloc.init
    notification.userInfo = { "owner" => owner.to_s }   
     
    notification.fireDate = NSDate.dateWithTimeIntervalSinceNow(time_interval)
    notification.timeZone = NSTimeZone.defaultTimeZone
    notification.repeatInterval = repeat

    notification.applicationIconBadgeNumber = badge_count if badge_count

    notification.alertBody = message
    # notification.alertAction = "Confirm"

    notification.soundName = sound

    notification.category = "time_up"

    # TODO set dismiss button message.


    app.scheduleLocalNotification(notification)

    pe_log "scheduled #{notification}, time_interval:#{time_interval}, badge_count:#{badge_count}, sound:#{notification.soundName}, owner:#{owner.to_s}" 

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

  #=

  def test_notification( notif )
    app.presentLocalNotificationNow( notif )
  end

  def notifications( owner = nil )
    app.scheduledLocalNotifications.select do |notif|
      if owner
        notif.userInfo && notif.userInfo["owner"] == owner.to_s
      else
        notif
      end
    end
  end
  

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

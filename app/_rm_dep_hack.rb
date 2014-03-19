# needed to work around dep issues for gem 'ib'
require 'ib/outlets'


module ProMotion
  module TableViewCellModule
  end
end


# motion_require "../lib/bblmotionkit/ui/ios/platform_integration"

# IOS
# PlatformViewController =  ProMotion::Screen

PlatformViewController =  ProMotion::Screen
PlatformView = UIView
PlatformWebView = UIWebView



# let's see if motion-require can take care of this now.

class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

class PEViewController < MotionKitViewController
end

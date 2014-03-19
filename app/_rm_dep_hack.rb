# needed to work around dep issues for gem 'ib'
require 'ib/outlets'


# motion_require "../lib/bblmotionkit/ui/ios/platform_integration"


# IOS
PlatformViewController =  ProMotion::Screen
PlatformView = UIView
PlatformWebView = UIWebView



# motion-require can't take care of this now.

class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

class PEViewController < MotionKitViewController
end

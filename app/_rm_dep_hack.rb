# needed to work around dep issues for gem 'ib'
require 'ib/outlets'


# TODO move into a file addition next to bblmotionkit.rb
if BW::App.ios?
  PlatformViewController =  ProMotion::Screen
  PlatformView = UIView
  PlatformWebView = UIWebView
else
  PlatformViewController =  NSViewController
  PlatformView = NSView
  PlatformWebView = WebView
end


# motion-require can't take care of this now.

class MotionViewController < PlatformViewController
end

class MotionKitViewController < MotionViewController
end

class PEViewController < MotionKitViewController
end


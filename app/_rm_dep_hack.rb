# needed to work around dep issues for gem 'ib'
require 'ib/outlets'


# TODO move into a file addition next to motionkit.rb
if BW::App.ios?
  PlatformViewController =  ProMotion::Screen
  PlatformView = UIView
  PlatformWebView = UIWebView
else
  PlatformViewController =  NSViewController
  PlatformView = NSView
  PlatformWebView = WebView
end


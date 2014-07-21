# needed to work around dep issues for gem 'ib'
# require 'ib/outlets'


# WORKAROUND incorrect load path order resulting in BW:App not defined when needed
module BW
  module App
    def self.ios?
      Kernel.const_defined?(:UIApplication)
    end
  end
end

if BW::App.ios?
  PlatformViewController =  ProMotion::Screen
  PlatformView = UIView
  PlatformWebView = UIWebView
else
  PlatformViewController =  NSViewController
  PlatformView = NSView
  PlatformWebView = WebView
end


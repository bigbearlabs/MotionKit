# work around blocking failures while refactoring to components.
class PageDetailsViewController < NSViewController
  include MsgLogging
end

# class WebInspectorWindowController
#   def init
#     o = self.initWithWindow(nil)
#     return o
#   end
# end
# EXPERIMENTAL duck-punch buggy webkit developer tool feature


#== some requires that got commented out, for possible future ref.

## InputFieldViewController
# require 'CocoaHelper'
# require 'appkit_additions'
# require 'KVOMixin'
# require 'defaults'

## LoggerMixin
# require "logger"

## CocoaHelper.rb
# require 'PERubyUtil'
# require 'KVCUtil'
# require 'KVOMixin'
# require 'LoggerMixin'
# require 'yaml'
# require 'net/http'


## PERubyUtil
# require 'cgi'
# require 'uri'
# require 'timeout'
# require 'open-uri'
# require 'benchmark'


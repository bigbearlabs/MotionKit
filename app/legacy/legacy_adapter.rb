# work around blocking failures while refactoring to components.
class PageDetailsViewController < NSViewController
  include MsgLogging
end


class Object
  # wrap BW::JSON
  def to_json
    case self
    when NSString
      '"' + self + '"'
    else
      BW::JSON.generate self
    end
  end
end


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


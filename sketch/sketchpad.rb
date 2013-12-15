# require 'set'

class Sketchpad

end



# NOTE doesn't work with objc selector invocations.
class DynamicDecorator
  def initialize(subject, do_before)
    @subject = subject
    @do_before = do_before
  end

  def method_missing(method, *args)
    @do_before.call method, *args

    @subject.send method, *args
  end

  def respond_to_missing?(method, include_private = false)
    pe_log "respond_to_missing: #{method}"
    @subject.respond_to_missing? method, include_private
  end

=begin
  def respondsToSelector(selector)
    pe_log "respondsToSelector: #{selector}"
    @subject.respondsToSelector selector
  end

  def methodSignatureForSelector(selector)
    pe_log "methodSignatureForSelector: #{selector}"
    @subject.methodSignatureForSelector selector
  end
=end
  
end


#==

# attempt to monkey-patch stdlib Logger to use gems requiring them. (peekaboo)
class Logger
  def initialize(*arg)
    @arg = arg
  end

  def info *args
    Log.info *args
  end
  
end
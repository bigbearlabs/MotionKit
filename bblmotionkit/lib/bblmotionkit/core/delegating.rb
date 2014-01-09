# a duck-typing-compliant replacement for Forwardable that works with RubyMotion.
# use with #extend, not #include.
module Delegating

  ## class-scope methods

  def def_delegator accessor_key_path, *methods
    raise "method_missing already defined" if self.methods.include? :method_missing

    self.send :include, InstanceMethods

    def_method_once :delegate_accessor do
      accessor_key_path
    end

    if methods.empty?
      # delegate all methods missing from client.
    else
      def_method_once :delegating_methods do
        methods
      end
    end
  end
  
  # TODO when extended, check if at risk of clobbering.


  module InstanceMethods

    def method_missing(method, *args)      
      # when delegating methods are specified
      if self.class.respond_to? :delegating_methods
        if self.class.delegating_methods.include?( method.intern)
          # send the method to the obj returned from the accessor instead.
          return self.delegate.send method, *args
        end
      else 
        # we defined the delegator in a generic way.
        if self.delegate.respond_to? method
          pe_log "delegating call #{method}"
          return self.delegate.send method, *args
        end
      end

      return super
    rescue Exception => e
      pe_report e, "delegating method '#{method}' to #{self.class.delegate_accessor}"
    end

    def respond_to_missing?(method, include_private = false)
      super || 
        if self.class.respond_to? :delegating_methods
          self.class.delegating_methods.include? method.intern
        else
          self.delegate.respond_to? method
        end
    end

    def respond_to?(method, include_private = false)
      super || self.respond_to_missing?( method, include_private)
    end

    # NOTE when mixed into an objc object, it will handle calls from ruby code but will miss calls from objc.

    # def respondsToSelector(selector)
    #   super || 
    #     if self.class.respond_to? :delegating_methods
    #       self.class.delegating_methods.include? selector.intern
    #     else
    #       # self.delegate.respondsToSelector(selector)
    #       # switch over to the ruby version to avoid manual conversions.
    #       self.respond_to? selector
    #     end
    # end

    # def methodSignatureForSelector(selector)
    #   super ||
    #     if self.class.respond_to? :delegating_methods
    #       self.delegate.methodSignatureForSelector selector
    #     else
    #       self.delegate.methodSignatureForSelector selector
    #     end
    # end

    # def forwardInvocation(invocation)
    #   pe_log "invoking #{self}##{invocation.selector} in forwardInvocation"
    #   if self.delegate.respondsToSelector(invocation.selector)
    #     invocation.invokeWithTarget(self.delegate)
    #   else
    #     super
    #   end
    #   # args = []
    #   # invocation.methodSignature.numberOfArguments.times do |i|
    #   #   args << 
    #   # end
    #   # self.delegate.send invocation.selector, *args
    # end
    

    def delegate
      self.kvc_get(self.class.delegate_accessor)
    end
  end

end


module DelegatingStub
  module ClassMethods
    
  end
  
  module InstanceMethods
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  # NOTE this doesn't work because we need to extend the client class - maybe we can use #extended.
end
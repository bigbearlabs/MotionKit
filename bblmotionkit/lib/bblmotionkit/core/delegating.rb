# a duck-typing-compliant replacement for Forwardable that works with RubyMotion.

module Delegating
  def def_delegator accessor, method
    self.send :include, InstanceMethods

    # FIXME can't handle multiple calls
    @@delegating_accessor = accessor
    @@delegating_method = method
  end

  def delegating_accessor
    @@delegating_accessor
  end
  
  def delegating_method
    @@delegating_method
  end
  
  # when extended, check if at risk of clobbering.


  module InstanceMethods
    def method_missing(method, *args)
      if self.class.delegating_method.to_s.eql? method.to_s
        # send the method to the obj returned from the accessor instead.
        self.send(self.class.delegating_accessor).send method, *args
      else
        super
      end
    end

    def respond_to?(method)
      super || (self.class.delegating_method.to_s.eql? method.to_s)
    end    
  end
end

# a duck-typing-compliant replacement for Forwardable that works with RubyMotion.

module Delegating
  def def_delegator accessor, *methods
    self.send :include, InstanceMethods

    # FIXME can't handle multiple calls
    @@delegating_accessor = accessor
    @@delegating_methods = methods.map &:intern
  end

  def delegating_accessor
    @@delegating_accessor
  end
  
  def delegating_methods
    @@delegating_methods
  end
  
  # when extended, check if at risk of clobbering.


  module InstanceMethods
    def method_missing(method, *args)
      if self.class.delegating_methods.include? method.intern
        # send the method to the obj returned from the accessor instead.
        self.send(self.class.delegating_accessor).send method, *args
      else
        super
      end
    end

    def respond_to?(method)
      super || (self.class.delegating_methods.include? method.intern)
    end    
  end
end

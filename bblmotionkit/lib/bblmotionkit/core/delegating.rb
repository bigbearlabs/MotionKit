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
      if self.class.respond_to? :delegating_methods and self.class.delegating_methods.include?( method.intern)
          # send the method to the obj returned from the accessor instead.
          self.delegate.send method, *args
      else
        if delegate.respond_to? method
          delegate.send method, *args
        else
          super
        end
      end
    rescue Exception => e
      pe_report e, "delegating method '#{method}' to #{self.class.delegate_accessor}"
    end

    def respond_to?(method)
      super || (self.class.delegating_methods.include? method.intern)
    end

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
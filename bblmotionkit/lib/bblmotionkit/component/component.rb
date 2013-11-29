module ComponentClient
  def setup_components( component_defs = self.components )
    component_defs.map do |component_def|
      component_class = component_def[:module]

      register component_class

      pe_log "assembled component #{component_class} into #{self}"
    end
  end

  def register component_class
    @registered_components ||= []

    # TACTICAL naive implementation keeps instantiating new instances..
    defaults = default "#{self.class.name}.#{component_class.name}"
    instance = component_class.new( self, defaults )
    @registered_components << instance

    # set up event method chaining.
    instance.event_methods.map do |event_method|
      self.chain event_method, instance.method(event_method)
    end

    # one-time setup.
    instance.on_setup
  end

  def chain method_name, method
    pe_log "TODO chain #{method} to #{method_name}"

    original_method = 
      if self.respond_to? method_name
        self.method method_name
      else
        # define a no-op method
      end

    do_chain = proc {
      method.call
      original_method.call
    }

    self.define_singleton_method method_name do
      do_chain.call
    end
  end

  # TODO wire platform events to registered components.
end


class BBLComponent
  attr_reader :client
  
  def initialize(client, defaults)
    raise "nil defaults" if defaults.nil?

    @client = client
    @defaults = defaults
  end

  def event_methods
    self.methods.grep /^on_/
  end

  #= MOVE

  def default key
    @defaults[key.to_s]
  end

  def set_default key, val

    pe_log "TODO persist #{key} with #{val}"

    default_def = self.defaults[key]
    postflight = default_def[:postflight]
    postflight.call(val) if postflight
  end
end


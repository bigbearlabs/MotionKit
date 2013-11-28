module ComponentAware
  def setup_components( component_defs = self.components )
    component_defs.map do |component_def|
      module_name = component_def[:module]

      # # mix into a new obj.
      namespace_obj = NamespaceModule.new
      namespace_obj.extend module_name

      # mix the thing into self.
      namespace_obj.extend_object self

      pe_log "assembled component #{module_name} into #{self}"
    end
  end
end

module BBLComponent

end

module NamespaceModule < Module
  def extend( another_module )
    prefix = naother_module.name
    
    # create a module that has same members with prefixed names.
    module_with_prefix = Module.new
    another_module.methods.map do |method_name|
      module_with_prefix.define_method "#{prefix}_#{method_name}" do |params|
        another_module.method method_name
      end
    end
    # TODO consts

    super module_with_prefix
  end
end

module DefaultBrowserHandler extend BBLComponent

  #= app lifecycle

  # UGH chaining these methods is tricky because namespace collision may already have occurred by the time self.included is called.
  # we can indirect the mixin op in #components and use a namespace obj.
  def on_setup
  end

  def on_terminate
  end

  #= 

  def make_default_browser
    previous_browser_bid = Browsers::default_browser
    unless NSApp.bundle_id.casecmp(previous_browser_bid) == 0
      pe_log "saving previous browser: #{previous_browser_bid}"
      set_default 'GeneralPreferencesViewController.previous_default_browser', previous_browser_bid
    end

    Browsers::set_default_browser NSApp.bundle_id
  end

  def revert_default_browser
    previous_browser_bid = default 'GeneralPreferencesViewController.previous_default_browser'
    Browsers::set_default_browser previous_browser_bid unless previous_browser_bid.empty?
  end

  #= 

  # prefs: on change, :default_browser should invoke appropriate method. probably can extract an on-off pattern for this.
end
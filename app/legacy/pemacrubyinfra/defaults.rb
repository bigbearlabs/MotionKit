# motion_require 'CocoaHelper'

module DefaultsAccess
  include KVC

  # LEAK
  def watch_default key, &handler
    @default_handlers_by_key ||= {}

    handlers = @default_handlers_by_key[defaults_qualified_key(key)] ||= []
    handlers << handler
  end
  

  def default( key )
    raise "factory defaults not set!" unless factory_defaults

    key = defaults_qualified_key key
    val = NSUserDefaults.standardUserDefaults.kvc_get(key)

    # retrieve from merged defaults.
    merged_defaults = 
      if val
        factory_defaults.overwritten_hash key => val
      else
        factory_defaults
      end

    # guard against flattened dupe key.
    final_val = merged_defaults.flattened_hash.unflattened_hash.kvc_get key

    pe_warn "nil value for default '#{key}'" if final_val.nil?
    debug [ self ] if final_val.nil?
    
    case final_val
    when 'YES' then true
    when 'NO' then false
    when NSDictionary then Hash[final_val]
    else
      final_val
    end
  end

  def set_default(key, val)
    pe_log "setting #{key}: #{val}"
    key = defaults_qualified_key key

    # construct the hash to save. retrieve tl hash, merge new val, diff from factory defaults.
    tl_key = key.split('.').first
    tl_hash = default(tl_key)

    unflattened_hash = { key => val }.unflattened_hash
    pe_log "unflattened: #{unflattened_hash}"
    
    merged_hash = tl_hash.overwritten_hash unflattened_hash[tl_key]
    pe_log "merged_hash: #{merged_hash}"

    new_hash = factory_defaults[tl_key].diff_hash merged_hash, new_keys: true

    pe_log "update new hash #{new_hash} for key #{tl_key}"

    NSUserDefaults.standardUserDefaults.setValue(new_hash, forKeyPath:tl_key)

    pe_log "set default #{key} successfully."

    if @default_handlers_by_key and (handlers = @default_handlers_by_key[key])
      handlers.map {|e| e.call key, val }
    end
  end

  # this leads to a SIGKILL.
=begin
  def defaults_register( factory_defaults )
    pe_debug "defaults_hash: #{factory_defaults}"
    # debug [ factory_defaults, {}, NSMutableDictionary.dictionary ]

    current_defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation
    
    # dictionary loaded using the cocoa api is not a true hash - work around by using reduce.
    remake_hash = lambda { |h|
      h.reduce({}) do |memo, k,v|
        memo[k] = v
        memo
      end
    }

    shipped_defaults_dup = remake_hash.call factory_defaults

    new_defaults = shipped_defaults_dup.overwritten_hash( remake_hash.call current_defaults )
    
    pe_debug "defaults to register: #{new_defaults}"

    NSUserDefaults.standardUserDefaults.registerDefaults( remake_hash.call new_defaults)  
  end
=end

  def factory_defaults
    NSApp.delegate.ivar(:factory_defaults)
  end

  # reserved to top-level module client (i.e. appd)
  def defaults_register( factory_defaults )
    pe_debug "defaults_hash: #{factory_defaults}"

    @factory_defaults = factory_defaults

    # previously we used to save redundant entries - make it lean.
    current_defaults = defaults_saved
    saved_delta = Hash[factory_defaults].diff_hash current_defaults.copy, new_keys: false
    
    pe_log "defaults to set: #{saved_delta}"

    # set.
    saved_delta.map do |k, v|
      set_default k, v
    end

    #  register merged hash in the volatile domain.
    merged_defaults = factory_defaults.overwritten_hash saved_delta
    NSUserDefaults.standardUserDefaults.registerDefaults(merged_defaults)
  end

  def defaults_saved
    NSUserDefaults.standardUserDefaults.persistentDomainForName(NSApp.bundle_id)  
  end
  
  def defaults_set_delta delta, key_qualifier = nil
    delta.map do |key, val|
      qualified_key = (key_qualifier ? "#{key_qualifier}.#{key}" : key)

      if val.is_a? Hash
        defaults_set_delta val, qualified_key
      else
        set_default qualified_key, val
      end
    end
  end
  
  def update_default_style( current_defaults, factory_defaults )
    # first inspect keys in current and find old-style entries.
    old_style_keys = []
    Hash[factory_defaults.to_a].each do |key, val|
      pe_log "search default for #{key}"
      # first check if the new-style entry exists.
      new_val = current_defaults[key]

      # check if the old-style entry exists.
      old_entry_key = key.split('.').first
      if default old_entry_key
        pe_log "found old-style entry: #{old_entry_key}"
        old_style_keys << old_entry_key

        # read val from old-style unless there's new style.
        if ! new_val
          old_val = NSUserDefaults.standardUserDefaults.kvc_get key

          # write out the user val in new style.
          pe_log "converting default #{key} to new style."
          set_default key, old_val
        end
      end
    end
    
    # remote old-style entry, save the diff.
    
    old_style_keys.uniq.each do |key|
      pe_log "remove old-style entry for #{key}"
      NSUserDefaults.standardUserDefaults.removeObjectForKey(key)
    end
  end

  def overwrite_user_defaults( keys, factory_defaults = @factory_defaults )
    keys.each do |key|
      val = factory_defaults.kvc_get(key)
      pe_log "overwriting user default for #{key} with #{val}"
      set_default key, val
    end
  end

  # doesn't work.
  def reset_default( key )
    key = defaults_qualified_key key
    NSUserDefaults.standardUserDefaults.removeObjectForKey(key)
  end
  
  def inject_defaults
    values = default self.defaults_root_key
    if ! values
      pe_warn "no default values for #{self}"
      return
    end
    
    values = values.dup
    pe_debug "default values for #{self.class.name}: #{values}"
    
    KVCUtil.make_hash_one_dimensional(values).each do |k,v|
      begin
        key_path_where_nil = nil_sub_key_path k

        self.kvc_path_init k
        self.kvc_set k, v
        pe_debug "set #{self}.#{k} to #{v}"
        debug if v == 'ignore'

        if key_path_where_nil
          pe_log "#{key_path_where_nil} is nil."
=begin
          @reaction_default = react_to k do |*args|
            if ! v
              pe_log "reacting to #{args} for #{key_path_where_nil}"
              self.kvc_set(k, v) unless ! self.kvc_get(key_path_where_nil)
              # FIXME this is non-recursive, therefore waiting to blow up again. make this method recursive in order to fix.
            end
          end
=end
        end

      rescue Exception => e
        pe_report e, "while trying to set #{self}.#{k}"
      end
    end

    pe_log "injected defaults for #{self}"
  end


  def defaults_root_key
    self.class.clean_name
  end

  # call with a symbol in order to access using the object's defaults_root_key.
  def defaults_qualified_key key
    raise "invalid key: #{key}" if key.to_s.empty?

    key = 
      if key.is_a? Symbol
        self.defaults_root_key + "." + key.to_s
      else
        key.to_s
      end
  end
  
  # defining the attr on inclusion due to sporadic crashes when using kvo in conjunction. #define_method looks dangerous.
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def default( attr_name )
      if self.class.method_defined? attr_name
        raise "accessor '#{attr_name}' already defined."
      end

      # add an accessor that falls back to the defaults value if ivar not set.
      define_method attr_name do
        val = ivar attr_name
        val ||= instance_exec do
          default "#{defaults_root_key}.#{attr_name}"
        end
      end

      # self.def_method "#{attr_name}=" do |val|
      #   instance_variable_set "@#{attr_name}", val
      # end
    end
  end

end

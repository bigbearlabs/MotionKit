motion_require 'CocoaHelper'

module DefaultsAccess
	include KVC

	# call with a symbol in order to access using the object's defaults_root_key.
	def default( key )
		raise "invalid key: #{key}" unless key

		if key.is_a? Symbol
			key = self.defaults_root_key + "." + key.to_s
		end

		val = NSUserDefaults.standardUserDefaults.kvc_get(key)

		pe_warn "nil value for default '#{key}'" if val.nil?
		debug [ self ] if val.nil?
		
		case val
		when 'YES' then true
		when 'NO' then false
		when NSDictionary then Hash[val.to_a]
		else
			val
		end
	end

	def set_default(key, value)
		key = key.to_s

		if key.index '.'
			# if e.g. keypath involves a dictionary in the middle, this will fail. so
			# retrieve the default object for 1st segment of keypath first, then kvc set value on that first.
			keypath_segment_1 = key.split('.').first
			default_for_keypath_segment_1 = default keypath_segment_1
			if ! default_for_keypath_segment_1
				raise  "default for #{keypath_segment_1} is nil, create new dict."
			end

			new_default = default_for_keypath_segment_1.deep_mutable_copy
			if value != default(key)
				new_default.kvc_set key.gsub( keypath_segment_1 + '.', '' ), value
			end
			# TODO for cleaner storage, subtract shipped defaults from new_default.

			the_key = keypath_segment_1
			the_val = new_default

		else
			the_key = key
			the_val = value
		end

		the_val = Hash.new.merge(the_val).to_stringified if the_val.is_a? NSDictionary

		NSUserDefaults.standardUserDefaults.setValue(the_val, forKeyPath:the_key)

		pe_log "set user default #{the_key} to #{the_val}"

	end

	# this leads to a SIGKILL.
=begin
	def defaults_register( shipped_defaults )
		pe_debug "defaults_hash: #{shipped_defaults}"
		# debug [ shipped_defaults, {}, NSMutableDictionary.dictionary ]

		current_defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation
		
		# dictionary loaded using the cocoa api is not a true hash - work around by using reduce.
		remake_hash = lambda { |h|
			h.reduce({}) do |memo, k,v|
				memo[k] = v
				memo
			end
		}

		shipped_defaults_dup = remake_hash.call shipped_defaults

		new_defaults = shipped_defaults_dup.overwritten_hash( remake_hash.call current_defaults )
		
		pe_debug "defaults to register: #{new_defaults}"

		NSUserDefaults.standardUserDefaults.registerDefaults( remake_hash.call new_defaults)  
	end
=end

	def defaults_register( shipped_defaults )
		pe_debug "defaults_hash: #{shipped_defaults}"

		current_defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation
		
		new_defaults = shipped_defaults.overwritten_hash( current_defaults.copy )
		
		pe_debug "defaults to register: #{new_defaults}"

		NSUserDefaults.standardUserDefaults.registerDefaults(new_defaults)

		# WORKAROUND we still get a lossy situation wrt the keyset. so explicitly set the top-level keys.
		new_defaults.each do |top_level_key, top_level_value|
			set_default top_level_key, top_level_value
		end
	end

	def update_default_style( current_defaults, shipped_defaults )
		# first inspect keys in current and find old-style entries.
		old_style_keys = []
		Hash[shipped_defaults.to_a].each do |key, val|
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

	def overwrite_user_defaults( keys, shipped_defaults )
		keys.each do |key|
			val = shipped_defaults.kvc_get(key)
			pe_log "overwriting user default for #{key} with #{val}"
			set_default key, val
		end
	end

	def restore_shipped_default( key )
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

	def update_default( property, val = self.kvc_get(property) )
		key = [ defaults_root_key, property ].join(".")
		set_default key, val
	end

	def defaults_root_key
		self.class.name.to_s
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
			# 	instance_variable_set "@#{attr_name}", val
			# end
		end
	end

end

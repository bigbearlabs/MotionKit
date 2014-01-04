# require 'CocoaHelper'

module KVOMixin
	
	# block params for handler: object, change, context
	def observe_kvo( object, key_path, &handler )
		key_path = key_path.to_s
		
		# create the observer as a hash with singleton kvo methods.
		observer = KVOObserver.new({ key_path:key_path, handler:handler, kvo_logging:object.kvo_logging })
	
		# context_pointer = Pointer.new :id
		# context_pointer.assign(observer)
		context_pointer = nil
		
		pe_debug "register #{observer} to #{object}, keypath #{key_path} on behalf of #{self}"
		object.addObserver(observer, forKeyPath:key_path, options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld, context:context_pointer)

		# add it to an array on the observed object, to guard against collection.
		object.add_observer observer
	end
	
	def remove_kvo(object, key_path)
		observers = self.kvo_observers.dup.select {|observer| observer[:key_path] == key_path }
		raise "no observer for object:#{object}, key_path:#{key_path}" if observers.empty?
		
		observers.each do |observer|
			object.removeObserver(observer, forKeyPath:key_path)
			pe_log "removed #{observer} from kvo obj: #{object}, key_path:#{key_path}"
			self.kvo_observers.delete observer
		end
	end
			
	# finalizer tears down observation.
	# def finalize
	#   if ! @mutex
	#     super
	#   else
	#     @mutex.lock
	#     if self.kvo_observers
	#       self.kvo_observers.allObjects.each do |observer|
	#         self.remove_kvo observer[:observee], observer[:key_path]
	#       end
	#     end
	#   
	#     super
	#     @mutex.unlock
	#   end
	# end

	class KVOObserver
		def initialize(params)
			@key_path = params[:key_path]
			@handler = params[:handler]
			@kvo_logging = params[:kvo_logging]
		end

		def observeValueForKeyPath(keyPath, ofObject:object, change:change, context:context)
			# self[:kvo_logging] = true   # for debugging

			if @kvo_logging
				pe_log "obj: #{object.inspect}"
				pe_log "change: #{change.inspect}"
				pe_log "context: #{context.inspect}"
			end
			
			case keyPath
			when @key_path
				# NOTE we can safely ignore the context pointer here since we don't have 'notification snatching' due to class hierarchy - one benefit of having an on-the-fly observer created to proxy the observation and relay to the handler.
				pe_log "kvo for #{@handler} with change:#{change}" if @kvo_logging
				@handler.call object, change, context
			else
				super
			end

		end
	end
end




# handy tool for adhoc observation.
class Watcher
	include KVOMixin
	
	attr_accessor :handler
	
	def initialize(&handler)
		super()
		self.handler = handler
	end
	
	def watch( object, key_path )
		observe_kvo object, key_path do |obj, change, context|
			handler.call(obj, change, context)
		end
	end
end   


# util.
class NSObject
	attr_accessor :kvo_logging
	
	# logs kvo state.
	def kvo_log
		# this guy needs to go through the NSLog formatted string log function in order to show up properly.
		self.observationInfo ? 
			self.observationInfo.to_object.description : 
			'no observations'
	end

	# perform an operation and send kvo change notification for a property.
	def kvo_change( prop, val = nil)
		self.willChangeValueForKey(prop.to_s)
		
		if block_given?
			yield prop
		else
			raise "call with val or block" if val.nil?
			
			instance_variable_set "@#{prop}", val
		end

		self.didChangeValueForKey(prop.to_s)
	end

#=

	def kvo_change_bindable( prop, condition = nil, &change_block )
		# bindings require changes to be made on main thread.
		bindings_compatible do
			should_call = true
			should_call = condition.call if condition
			if should_call
				kvo_change prop, &change_block
			else
				pe_debug "condition returned false, not changing #{prop}"
			end
		end
	end

	# use when there's risk of redundant notifications, e.g. setting kvc attr's.
	def bindings_compatible(&block)
		on_main( &block)
	end
	
#=

	# keeping track of registrations.
	attr_accessor :kvo_observers    

	def add_observer( observer )
		# hold a ref to observer to guard against collection
		self.kvo_observers ||= []
		self.kvo_observers << observer    
	end

end


# change dictionary queries.
class NSDictionary

	def kvo_added
		kvo_new.to_a - kvo_old.to_a
	end

	def kvo_removed
		kvo_old.to_a - kvo_new.to_a
	end

	def kvo_new
		self[NSKeyValueChangeNewKey]
	end

	def kvo_old
		self[NSKeyValueChangeOldKey]
	end
end

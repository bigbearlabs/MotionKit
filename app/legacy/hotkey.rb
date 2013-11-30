class HotkeyManager
	include DefaultsAccess
	include KVOMixin
	include Reactive

	attr_reader :registrations

	attr_accessor :modkey_status, :key_down, :modkey_counter


	def defaults_root_key
		'WebBuddyAppDelegate.hotkey_manager'
	end


	def initialize

		@registrations = {}

		init_modkey_reactions
	end


	# register with a hash containing :id, :defaults_key, :handler.
	def add_hotkey_definition( details )
		hotkey_def.defaults_key = details[:defaults_key]

		hotkey_def.keycode = default "#{defaults_key}.keycode"
		hotkey_def.flags = default "#{defaults_key}.flags"

		System.register_hotkey_def hotkey_def do
      details[:handler].call event, params
		end
		
		# hold it
		@registrations[hotkey_def.id] = hotkey_def

		# update defaults
		set_default defaults_key, {
			keycode: keycode,
			flags: flags
		}

	rescue Exception => e
		pe_warn e
	end
	# TODO System
	# TODO find and dust off the object that can be used with a hash-like interface.

	class System
		@@hotkey_center = DDHotKeyCenter.new

		# @assert platform-specific
		# interface with cocoa / 3rd-party lib to register the hotkey def.
		def self.register_hotkey_def hotkey_def

			keycode = hotkey_def.keycode.to_i
			flags = hotkey_def.flags.to_i
			
			# unregister previous
			@@hotkey_center.unregisterHotKeysWithTarget(self, action:'handle_hotkey_event:params:')
			
			# register new
			if ! @@hotkey_center.registerHotKeyWithKeyCode(keycode, modifierFlags:flags, target:self, action:'handle_hotkey_event:params:', object:nil)
				raise 'hotkey registration failed'
			else
				pe_log "hotkey registered: #{keycode}, #{flags}"

			end
		end
	end

#= modkey

	def init_modkey_reactions
		react_to :modkey_status do |args|
			pe_debug "keys: #{args}"
			self.react_to_modkey
		end

		react_to :key_down do |args|
			pe_debug "keys: #{args}"
			self.react_to_key_down
		end
	end

	def add_modkey_action_definition( details )
		# client passes block, we register on system layer and watch for the action.
		# if it involves timers, encapsulate implementation details here.

		@modkey_def = details

		self.modkey_counter ||= 0

		global_handler = -> event {
			self.on_nsevent event, details
			nil
		}
		local_handler = -> event {
			self.on_nsevent event, details
			event
		}

		@handlers ||= {}
		@handlers[:flags_global] = NSEvent.addGlobalMonitorForEventsMatchingMask(NSFlagsChangedMask, handler:global_handler)
		@handlers[:flags_local] = NSEvent.addLocalMonitorForEventsMatchingMask(NSFlagsChangedMask, handler:local_handler)

		@handlers[:key_global] = NSEvent.addGlobalMonitorForEventsMatchingMask(NSKeyDownMask, handler:global_handler)
		@handlers[:key_local] = NSEvent.addLocalMonitorForEventsMatchingMask(NSKeyDownMask, handler:local_handler)

		pe_log "set up modkey action for #{details}"
	end

	def remove_modkey_action_definition
		return unless @handlers

		@handlers.values.map do |handler|
			NSEvent.removeMonitor(handler)
		end
	end

	# event handlers

# SKETCH
# states: global modkey state, last key down
# reactions: on modkey down, start double-down timer
# on modkey down before double-down timer fires, emit double-down event
# on modkey down, start hold timer
# on modkey up, invalidate hold timer
# on key down, invalidate all timers
#
# on hold timer fire, emit hold event
# on hold event, show page detail if window active.

# LESSON should model an event history and detection based on analysing this model object. the granularity lesson, similar to the one from WebViewDelegate.
	def react_to_modkey
		case self.modkey_status
		when :up
			if self.modkey_counter == 2
				pe_debug "modkey default action."
				
				self.modkey_counter = 0

				@modkey_def[:handler].call

			else
				@modkey_timer.invalidate if @modkey_timer

				pe_debug "# counter reset timer"
				@modkey_timer = NSTimer.new_timer default(:modkey_double_threshold) do
					pe_debug "timer reached - counter #{self.modkey_counter}"
					self.modkey_counter = 0
				end
			end

			pe_debug "# invalidate hold timer"
			if NSApp.active?
				@modkey_hold_timer.invalidate if @modkey_hold_timer
			end

		when :down
			self.modkey_counter += 1

			pe_debug "# start hold timer"

			@modkey_hold_timer = NSTimer.new_timer default(:modkey_hold_interval) do
				pe_debug "hold timer reached"

				# fire hold handler if modkey was held.
				if self.modkey_status == :down
					@modkey_def[:handler_hold].call
				end
			end

		else
			pe_warn "unknown modkey_status #{self.modkey_status}"
		end
	end

	def react_to_key_down
		pe_debug "reset all state"
		self.modkey_counter = 0
		@modkey_hold_timer.invalidate if @modkey_hold_timer
	end

	def on_nsevent( event, details )
		pe_debug "got #{event}, type: #{event.type}, keycode: #{event.keyCode}, modifiers: #{event.modifierFlags}"

		case event.type
		when NSFlagsChanged
			if event.keyCode != 0
				modkey_status = event.modifier_down?(details[:modifier]) ? :down : :up
				self.kvc_set_if_needed :modkey_status, modkey_status
			end
		when NSKeyDown
			self.key_down = event.keyCode
		else
			pe_warn "unhandled event type #{event.type}"
		end
	end		
end


class HotkeyViewController < PEViewController
	# views
	attr_accessor :recorder_control
	
	# bindable properties
	attr_accessor :description
	
	# model object
	attr_accessor :hotkey_registration 

	def awakeFromNib
		super
		
		# populate the bindables
		self.description = @hotkey_registration[:id]
		@recorder_control.delegate.setupRecorderControlWithKeyCode( hotkey_registration[:keycode], flags: hotkey_registration[:flags] )
	end
	
	def register_hotkey(keycode, flags:flags)
		pe_log "hotkey for #{self} updated to #{keycode}, #{flags}"
		
		@hotkey_registration.register_hotkey(keycode, flags:flags)
	end
		
end

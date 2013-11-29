class HotkeyHandler < BBLComponent

	attr_accessor :hotkey_manager

	def initialize(arg)
		super

		@hotkey_manager ||= HotkeyManager.new

		@hotkey_policy = default :hotkey_policy
		@hotkey_action_policy = default :hotkey_action_policy
	end

	def on_setup
		@hotkey_manager.remove_modkey_action_definition  # necessary for no-op.

		if default :enable_hotkey_dtap
			self.setup_hotkey_dtap
		end
	end

	def setup_hotkey_dtap
		execute_policy :hotkey  # TODO this usage of policy looks very unnatural
	end

	# policies
	# NOTE this was the attempt to make have the feature switcheable on/off using the pref. it didn't work out so well.

	def hotkey_noop( params )
	end
	
	def hotkey_enabled( params )
		@dtap_definition = {
			modifier: default(:hotkey_modkey),
			handler: -> {
				execute_policy :hotkey_action
			},
			handler_hold: -> {
				if ! NSApp.active? && @hotkey_manager.modkey_counter == 2
					self.on_double_tap_hold
				else
					NSApp.send_to_responder "handle_show_page_detail:", self
				end
			}
		}

		# set up the modkey.
		@hotkey_manager.add_modkey_action_definition @dtap_definition

=begin
		@hotkey_manager.add_hotkey_definition( {
			id: :activation,
			defaults_key: 'hotkeys.activation',

		self.update_toggle_menu_item
=end
	end
	
	def hotkey_action_activate_main_window( params )
		NSApp.delegate.toggle_main_window({ activation_type: :hotkey })
	end

	def hotkey_action_activate_viewer_window( params )
		NSApp.delegate.toggle_viewer_window
		
		# # temporarily mirror with main window.
		# if ! current_viewer_wc.window.visible  # taking advantage of main runloop
		# 	self.activate_main_window
		# end
		#
		# it2
		self.main_window_shown = ! self.main_window_shown
	end

	#= modkey pref CLEANUP

	def handle_modkey_change( event )
		pe_log "flags changed!! #{event.description}"
			
		# when released, stop carouselling, invalidate mod key timer.
		if activation_modifier_released?
			
			if @hotkey_action_policy == "switcher"
				stop_carouselling if carouselling
			end

			@modkey_timer.invalidate if @modkey_timer

		else
			# the app is in the foreground and modifier is pressed.
		end
	end

	#= events

	def on_double_tap_hold
		self.activate_viewer_window

		# NSApp.send_to_responder "handle_show_page_detail:", self

		# oh, the dream.
		# NSApp.delegate.handle_show_app_actions

		wc.hide_input_field
	end

#== modifier related
# REFACTOR push up.

	def setup_modkey_monitoring(&block)
		# watch the modifier keys.
		# e.g. opt modifier down -> up:
		# I, [2012-12-10T20:26:20.987551 #680]	INFO -- : flags changed!! NSEvent: type=FlagsChanged loc=(0,874) time=522965.8 flags=0x80140 win=0x0 winNum=100661 ctxt=0x0 keyCode=61
		# I, [2012-12-10T20:26:21.381591 #680]	INFO -- : flags changed!! NSEvent: type=FlagsChanged loc=(0,874) time=522966.2 flags=0x100 win=0x0 winNum=100661 ctxt=0x0 keyCode=61
		NSEvent.addLocalMonitorForEventsMatchingMask(NSEventMaskFromType(NSFlagsChanged), handler: -> event {
			block.call event
			event
		})
	end

	def setup_modkey_held_action(&block)
		@modkey_timer = NSTimer.new_timer self.modkey_hold_interval do
			unless activation_modifier_released?
				block.call
			end
		end
	end

	def activation_modifier_released?
		registrations = @hotkey_manager.registrations[:activation]

		if ! registrations
			pe_warn "no hotkey registrations!"
			return false
		end

		flags = @hotkey_manager.registrations[:activation][:flags]

		! NSEvent.modifiers_down?( flags )
	end

end


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

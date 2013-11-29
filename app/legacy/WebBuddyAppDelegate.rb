# require 'debugging'


class WebBuddyAppDelegate < PEAppDelegate
	include ComponentClient
	include KVOMixin
	include Reactive

	include InputHandler
	include ServicesHandler

	# collaborators

	# we modelled the domain a bit inaccurately with regards to things like 'page'.
	attr_accessor :user

	# outlets
	attr_accessor :toggle_menu_item

	attr_accessor :main_window_controller
	attr_accessor :context_gallery_vc  # RENAME the page collection vc.

	# observable state - gradually migrate observation to frp-style.
	attr_accessor :active_status  # RENAME main window status

	def components
		[
			{
				module: DefaultBrowserHandler,
			},
			{
				module: HotkeyHandler,
			},
			# {
			# 	module: ServicesHandler,
			# },
		]
	end


#= major lifecycle

	def setup

		super

		setup_components

		@intro_enabled = default :intro_enabled
		@load_welcome = default :load_welcome

		@load_ext_url_policy = default :load_ext_url_policy

		# deprecated / unused defaults
		# @selection_grab_enabled = default :selection_grab_enabled
		# @show_input_field_on_hotkey = default :show_input_field_on_hotkey


		# important domain object
		self.user = User.new

		if $DEBUG
			periodically do
				pe_log "mainWindow: #{NSApp.mainWindow}, keyWindow: #{NSApp.keyWindow}"
				pe_log "responder chain: #{NSApp.keyWindow.responder_chain}" if NSApp.keyWindow
			end
		end
	end

	def setup_part2
		super

		observe_notification :Activation_notification

		# user actions
		observe_notification :Visit_request_notification
		observe_notification :Revisit_request_notification
		observe_notification :Site_search_notification
		observe_notification :Filter_spec_updated_notification
		
		# the app's domain model / storage scheme.
		self.setup_context_store

		try {
			watch_notification NSWindowDidEndLiveResizeNotification
			watch_notification NSWindowDidMoveNotification
		}

		try {
			trace_time :setup_part2_2, true do
				self.setup_part2_2
			end
		}
	end

	def setup_part2_2

		try {
			# after introducing modkey double-down / hold actions, this is now out of date 
			if @hotkey_action_policy == "switcher"
				self.setup_kvo_carousel_state

				self.setup_modkey_monitoring do |event|
					self.handle_modkey_change event
				end
			end
		}

		try {
			setup_display_set_change_handling
		}

		try {
			self.setup_main_window

			apply_preferences  # TACTICAL

			NSApp.activate

			if @intro_enabled
				self.load_intro
			else
				trace_time :load_start, true do
					self.load_start
				end
			end
		}

	end

	# the bit that happens after the intro.
	def load_start

		@ready_to_load = true

		if @pending_handlers && (! @pending_handlers.empty?)
			@pending_handlers.each do |handler|
				handler.call
			end
			@pending_handlers.clear
		else
			if @load_welcome
				on_main {
					self.load_welcome_page
				}
			end
		end

	end


#= setup

	def setup_defaults
		super

		# shitty hack to up-version the defaults.
		# using a previous version will then become wonky.
		# there's got to be a better way to do this.
		overwrite_user_defaults [
			'WebBuddyAppDelegate.load_ext_url_policy',
			# 'WebBuddyAppDelegate.hotkey_manager.modkey_hold_interval',
			# 'WebBuddyAppDelegate.hotkey_manager.modkey_double_threshold',
			# FIXME why do nested properties not work properly?
		], defaults_hash
	end

	def apply_preferences
		self.preferences_by_id.values.map do |preference|
			key = preference[:key] || preference[:name]
			val = default key

			postflight = preference[:postflight]
			if postflight
				pe_log "applying preference #{key}"
				postflight.call val
			# REDUNDANT if these need to map to properties, define a postflight.
			# elsif ! val.nil?
				# self.kvc_set key, val
			else
				"no postflight or val for preference '#{key}', doing nothing."
			end
		end
	end

	# NOTE if prefs can be lined up to the component abstraction, we can get rid of this method and split up the contents in each component instead.
	def preferences_by_id
		{
			9001 => {
				name: :enable_default_url_handler,
				postflight: -> val {
					# TODO needs to register an app quit event handler instead.
#					if val
#						NSApp.delegate.make_default_browser
#					else
#						NSApp.delegate.revert_default_browser
#					end
				}
			},
			9003 => {
				name: :enable_input_field,
			},
			9004 => {
				name: :enable_gallery,
				postflight: -> val {
					NSApp.delegate.setup_gallery
				}
			}
		}
	end

	def setup_context_store
		@context_store = ContextStore.new

		@context_store.load

		self.user.context = @context_store.current_context
	end

	
#= IBActions for menu

	def handle_show_gallery( sender )
		self.main_window_shown = true
	end

	def handle_hide_gallery( sender )
		self.main_window_shown = false
	end

	def toggle_front( sender )
		self.toggle_viewer_window
	end

#= intro

	def load_intro(sender = nil)
		wc.do_activate
		wc.window.center

		url = NSBundle.mainBundle.url 'modules/intro/index.html'

		self.load_url url.absoluteString, { 
			interface_callback_handler: self
		}
	end

	def show_arrow
		on_main_async {
			pe_log "time to show the arrow. #{self}"

			@arrow_wc ||= ArrowWindowController.alloc.init

			@arrow_wc.show
		}

		nil
	end

	def hide_arrow
		@arrow_wc.close if @arrow_wc
	end

	def complete_intro
		on_main_async {
			pe_log "intro finished."

			self.hide_arrow

			# any further cleanup?


			# update the default so the initial panel doesn't show next time.
			set_default 'WebBuddyAppDelegate.intro_enabled', false

			self.load_start
		}

		nil
	end

#= content loading

	def load_welcome_page
		url = default :welcome_url
		
		if ! network_connection?
			pe_log "no network connectivity. showing local welcome page"
			url = NSBundle.mainBundle.url( 'modules/welcome/index.html' ).absoluteString
		end
			
		self.load_url url
	end

	def load_url(url_string, details = {})
		# debug [ url_string, details ]
		wc.do_activate.load_url url_string, details
	end
	
#= activation / deactivation

	def deactivate_if_needed
		#		main_window.orderOut(self)

		visible_windows = self.visible_windows.select do |w|
			w.isOnActiveSpace
		end
		pe_debug "visible windows on space: #{visible_windows}"
		if visible_windows.empty?
			NSApp.hide(self)
		end
	end

	# TODO delay until space state stabilises.
	def handle_Activation_notification( notification )
		NSApp.activate
		self.activate_viewer_window
	end

#= user actions
	
	def handle_Visit_request_notification( notification )
		new_location = notification.userInfo
		self.load_url new_location.to_url_string, track_id: 'stub-visit-track'
	end
	
	def on_Revisit_request_notification( notification )
		url = notification.userInfo.url
		self.load_url url, track_id: notification.userInfo.track_id
	end

	def on_Site_search_notification(notification)
		search_details = notification.userInfo

		wc.do_activate.do_search search_details
	end

	# FIXME move to the wc.
	def on_Filter_spec_updated_notification( notification )
		filter_spec = notification.userInfo

		# @main_window_controller.filter filter_spec
		wc.filter filter_spec
	end

#= tracks

	def track_id_app
		result = @current_app
		if ! result || result =~ /#{NSApp.name}/
			result = @previous_app
		end
		result
	end


#= prefs
	
	def new_pref_window(sender)
		flavour = case sender.tag
			when @tags_by_description['menu_item_prefs_DEV']
				:dev
			else
				:standard
			end

		@prefs_window_controller = PreferencesWindowController.alloc.init( {
			hotkey_manager: @hotkey_manager,
			flavour: flavour
		})
		@prefs_window_controller.showWindow(self)
		@prefs_window_controller.window.makeKeyAndOrderFront(self)

		# we need this in order to avoid the window opening up but failing to catch the user's attention.
		NSApp.activate
	end

	def handle_Preference_updated_notification( notification )
		# TODO check if display set changed, process window frame as necessary

		self.update_toggle_menu_item
	end
	
#= content loading from system

	Keycodes = {
		shift: NSShiftKeyMask,
		opt: NSAlternateKeyMask
	}

	# the handler for url invocations from the outside world.
	def on_get_url( details )
		url_event = details[:url_event]
		url = details[:url]

		current_modifiers = NSEvent.modifiers

		# HACK!!! very brittle coupling to defaults structure
		handler_specs = default 'GeneralPreferencesViewController.click_handler_specs'

		# dispatch to the right handler spec based on what keys are pressed.
		if ( (current_modifiers & Keycodes[:shift]) != 0 && ( current_modifiers & Keycodes[:opt]) != 0 )
			bundle_id = handler_specs[2][:browser_bundle_id]
		elsif (current_modifiers & Keycodes[:opt]) != 0
			bundle_id = handler_specs[1][:browser_bundle_id]
		else
			bundle_id = handler_specs[0][:browser_bundle_id]
		end

		load_url_proc = -> {
			pe_debug "open #{url} with #{bundle_id}"
			self.open_browser bundle_id, url
		}

		# if @main_window_controller
		load_url_proc.call
		# else
		# 	@pending_handlers ||= []
		# 	@pending_handlers << load_url_proc
		# end
	end

	# OBSOLETE salvage any difference and remove.
	def open_browser(browser_id, url_string)	
		pe_log "request to handle url in #{browser_id}"
		
		case browser_id
		# me!!!
		when /#{NSApp.bundle_id}/i
			load_ext_url_in_space_window url: url_string

			return
			
		# some special cases for space-aware url opening.
		when :Safari
			@browser_process = SafariProcess.new @spaces_manager
			@browser_process.open_space_aware url_string
		when :Chrome
			@browser_process = ChromeProcess.new @spaces_manager
			@browser_process.open_space_aware url_string
		else
			super
		end
	end
	
	#= policies

	def load_ext_url_in_main_window( params )
		self.main_window_shown = true

		@main_window_controller.load_url params[:url]
	end

	# RENAME load_ext_url_in_viewer
	def load_ext_url_in_space_window( params )
		url = params[:url]

		self.current_viewer_wc
			.do_activate
			.load_url url, track_id: track_id_app
	end

	# RENAME load_ext_url_in_app_viewer
	def load_ext_url_in_viewer( params )
		# state tracking
		@viewers_by_pname ||= Hash.new do |h,k|
			h[k] = self.new_viewer_window_controller
		end

		url = params[:url]

		# manage viewers based on invoking app.
		invoking_app = @previous_app

		# init a new viewer and send the stuff.
		pe_log "open #{url} on a viewer for #{invoking_app}"

		viewer_wc = @viewers_by_pname[invoking_app]

		viewer_wc.load_url url
		viewer_wc.show

		NSApp.activate
	end

#= view-layer preliminary

	attr_accessor :window_active
	attr_accessor :main_window_shown

#= current window

	def wc
		# @main_window_controller
		self.current_viewer_wc
	end

	def handle_new_window( sender )
		new_viewer_window # STUB
	end

#= main window

	def setup_main_window
		self.new_main_window

		self.main_window_shown = false
		# self.restore_main_window_frame
		# @main_window_controller.do_hide

	end

	def new_main_window
		# subsystems
		# @anchor_window_controller.load_anchor_for_space @spaces_manager.current_space_id, true
		self.main_window_controller = MainWindowController.alloc.init
		@main_window_controller.setup
		@main_window_controller.context = @context_store.current_context

		# @context_gallery_vc.setup

		## incomprehensibly, the key view loop breaks until a toolbar customisation occurs. so do this when waking up.
		# @main_window_controller.window.toolbar.displayMode = NSToolbarDisplayModeIconAndLabel
		# @main_window_controller.window.toolbar.displayMode = NSToolbarDisplayModeIconOnly

		## set up the gallery view
		# overlay_window = TransparentWindow.alloc.init(@main_window_controller.window.contentView.frame)
		# self.window.addChildWindow(overlay_window, ordered:NSWindowAbove)
		# @context_gallery_vc.frame_view = overlay_window.contentView
		# overlay_window.contentView.addSubview @context_gallery_vc.view # temp hack
		# @context_gallery_vc.view.snap_to_top

		# @context_gallery_vc.load_startup_state
		# @main_window_controller.show_gallery_view(self)

		@main_window_controller
	end
	
	def update_main_window_state
		# follows viewer window state + TODO was window shown on space.
		self.main_window_shown = ! self.wc.window.visible
	end

	def toggle_main_window(sender)

		# FIXME disable before hotkey is set.

		# FIXME .active_status smells very badly.

		should_activate = ! @main_window_controller.window.active?
		pe_debug "should_activate: #{should_activate}"

		if should_activate
			self.active_status = :activating

			activation_params = execute_policy :parse_activation_parameters
			self.user.perform_activation activation_params	

		else
			self.active_status = :deactivating
			self.hide_main_window(sender)
			# TODO refactor to a user#perform_*
		end
	end

	def activate_main_window
		@main_window_controller.do_activate -> {
			self.active_status = :activated
		}
	end
	
	def deactivate_main_window
		@main_window_controller.do_deactivate -> {
			self.active_status = :deactivated
		}
	end
	
	def hide_main_window(sender)
		self.main_window_shown = false
	end
	
#= viewer window

	def toggle_viewer_window

		if current_viewer_wc.window.active?
			self.deactivate_viewer_window
		else
			self.activate_viewer_window
		end
	end
	
	def activate_viewer_window
		self.current_viewer_wc.do_activate
		self.current_viewer_wc.show_input_field
		
		NSApp.activate

		self.update_main_window_state
	end

	def deactivate_viewer_window
		current_viewer_wc.do_deactivate

		on_main_async do
			self.update_main_window_state
		end
	end
	
	def new_viewer_window_controller initially_visible = true
		pe_log "initialising a new viewer."

		current_space_id = @spaces_manager.current_space_id
		viewer_wc = nil

		trace_time 'viewer_wc init' do
			viewer_wc = ViewerWindowController.alloc.init
		end

		# abort if space changed in the meantime.
		if current_space_id == @spaces_manager.current_space_id
			viewer_wc.window.visible = true

			viewer_wc.window.visible = initially_visible
		else
			raise "space changed while creating new viewer_window_controller"
		end
		
		trace_time 'viewer_wc setup' do
			viewer_wc.setup
		end
		trace_time 'viewer_wc set_context' do
			# viewer_wc.context = @context_store.new_context viewer_wc.to_s
			viewer_wc.context = @context_store.current_context
		end

		viewer_wc
	end


	def current_viewer_wc
		@viewer_controllers_by_space ||= Hash.new do |h,k|
			h[k] = self.new_viewer_window_controller
		end

		viewer_wc = @viewer_controllers_by_space[@spaces_manager.current_space_id]
		pe_log "retrieved #{viewer_wc} for space #{@spaces_manager.current_space_id}"

		# update the current context.
		@context_store.current_context = viewer_wc.context

		# HACK update main wc's context.
		# @main_window_controller.context = @context_store.current_context #TEMP

		viewer_wc
	end

	def handle_destroy_window( sender )
		current_viewer_wc.window.releasedWhenClosed = true  # TODO set once in nib.
		current_viewer_wc.should_close = true
		current_viewer_wc.window.close

		@viewer_controllers_by_space.delete_value current_viewer_wc
	end

#= system events

	def on_terminate
		@context_store.save
	end

	def on_will_become_active
	end

	def on_active
		pe_debug "became active"
		pe_debug "windows: " + NSApp.windows_report

		window_controller = wc
		# window_controller.do_activate if window_controller
	end
	
	def on_will_resign
		pe_debug "resign active"
		
		if @ready_to_load
			main_window = NSApp.mainWindow
			if main_window.is_a? MainWindow
				pe_log "window.shown:#{main_window.shown?}, window.active:#{main_window.active?}, fronting needed:#{main_window.shown?}"
			else
				pe_log "mainWindow: #{main_window}"
			end
			
			# mask window fronting is unfinished - its state must be correctly saved and restored with space changes.
			# @main_window_controller.window.front_with_mask_window if @main_window_controller.window.shown?
			
			@context_store.save
		end

	end
	
	def on_screen_change( notification )
		@screens_manager.handle_display_set_changed

		# on_main_async do
		# 	wc = self.current_viewer_wc
		# 	wc.window.visible = false
		# end
	end

	def on_space_change( notification )
		pe_log "space changed: #{notification.description}"

		@spaces_manager.space_changed

		# update_main_window_state

		# bring the window set for this space up to date.
		# cases:
		# - no window for space 
		#  [AnchorWindow:17222048960>, IRBWindow:17227767040>]
		# - duplicate viewer windows for space
		#  [AnchorWindow:17208655200>, MainWindow:17208957600>, MainWindow:17227692704>, IRBWindow:17227767040>, IRBWindow:17237527840>]
		# - duplicate viewer windows and main window for space.
		# [MainWindow:17205275200>, AnchorWindow:17208655200>, MainWindow:17208957600>, MainWindow:17227692704>, IRBWindow:17227767040>, IRBWindow:17237527840>]
		viewer_windows = @spaces_manager.windows_in_space.select { |e| e.windowController.is_a? ViewerWindowController }
		if viewer_windows.size > 1
			pe_warn "multiple viewer windows detected. just keeping the first"
			viewer_windows[1..-1].map do |redundant_window|
				redundant_wc = redundant_window.windowController

				redundant_window.close
				
				pe_log "closed window for #{redundant_wc}, mapped to space #{@viewer_controllers_by_space.key redundant_wc}"
				
				debug [redundant_wc, @spaces_manager.windows_in_space, @spaces_manager.current_space_id, @viewer_controllers_by_space ]
				
				@viewer_controllers_by_space.delete_value redundant_wc
			end
		end
	end

	def handle_NSWindowDidEndLiveResizeNotification( notification )
		pe_debug notification.description

		# slightly delay the saving in order to stay clear of the possibility that the wrong bounds gets saved when a resize is forced due to screen set change (i.e. when we must restore the bounds)
=begin
		if notification.userInfo == @main_window_controller.window
			DelayedExecution.new 1, -> {
				save_main_window_frame
			}
		end
=end
	end

	def handle_NSWindowDidMoveNotification( notification )
=begin
		if notification.userInfo == @main_window_controller.window
			DelayedExecution.new 1, -> {
				save_main_window_frame
			}
		end
=end
	end

#= menu
	
	def validateMenuItem( item )
		pe_debug "validate menu item #{item}"
		pe_log "responder chain: #{NSApp.mainWindow.responder_chain}" if NSApp.mainWindow

		# precondition to implementation: main_window_controller should have been initialised.
		# return false unless @main_window_controller && @main_window_controller.window

		case item.tag
		when @tags_by_description['menu_item_debug_console']
			# REFACTOR pull up
			# disable the debug console menu item unless build conf == debug.
			return Environment.instance.isDebugBuild

		when @tags_by_description['menu_item_toggle_main_window']
			# update the menu item text.
			@toggle_menu_item.title = 
				if wc.window.visible
					wc.window.active? ? 'Hide' : 'Bring to Front'
				else
				  'Show'
				end

			return true
		end

		# by default, enable items.
		true
	end
	
#= status item

	def handle_status_menu_click( sender )
		self.hide_arrow

		super
	end

	def status_item_image
		NSImage.imageNamed('status_item')
	end


#== disply set

	def setup_display_set_change_handling
		register_display_set_change_handler
	end			

	def register_display_set_change_handler
		@screens_manager.add_change_handler -> previous_display_set, display_set {
			pe_log "display set change handler - #{previous_display_set}, #{display_set}"
			
			restore_main_window_frame
		}
	end

#= window frame save / load - redundant?
	def save_main_window_frame
		@screens_manager.set_display_set_data @screens_manager.current_display_set_id, 'main_window', {
				'frame'=> @main_window_controller.window.frame.to_array
		}
	end

	def restore_main_window_frame
			data = @screens_manager.display_set_data @screens_manager.current_display_set_id
			if data && data['main_window']
				frame = data['main_window']['frame']
				pe_log "setting main window frame to #{frame}"

				@main_window_controller.window.frame = frame
				@main_window_controller.resize_overlay
			end
	end




#= menu
	
	def update_toggle_menu_item
		@key_code_transfomer ||= SRKeyCodeTransformer.alloc.init

		hotkey_keycode = @hotkey_manager.registrations[:activation][:keycode]
		hotkey_flags = @hotkey_manager.registrations[:activation][:flags]
		
		if @toggle_menu_item
			# update key equivalent
			translated_key_code = @key_code_transfomer.transformedValue( hotkey_keycode )
			# uncapitalise if shift not in mod mask.
			if (hotkey_flags & NSShiftKeyMask == 0)
				translated_key_code = translated_key_code.downcase
			end

			# handle the space key_code.
			if (translated_key_code.downcase.eql? 'space')
				translated_key_code = ' '
			end

			@toggle_menu_item.setKeyEquivalent( translated_key_code )
			@toggle_menu_item.setKeyEquivalentModifierMask( hotkey_flags )
		end
	end
	
#= carouselling

	def setup_kvo_carousel_state
		# watch active status to set the carouselling.
		observe_kvo self, :active_status do |k,c,ctx|
			pe_log "active_status #{active_status}"
			case active_status
			when :activating, :activated
				# carouselling if mod key down.
				if ! activation_modifier_released?
					start_carouselling
				else
					# turn carouselling off.
					stop_carouselling
				end
			else
				stop_carouselling
			end
		end

		# watch carouselling status to load selected tool.
		# observe_kvo self, :carouselling do |k,c,ctx|
		# 	if self.carouselling
		# 		show_switcher
		# 	else
		# 		load_selected_tool
		# 	end
		# end
	end

	attr_accessor :carouselling

	def start_carouselling
		self.carouselling = true

		self.show_switcher
	end

	def stop_carouselling
		self.carouselling = false

		load_selected_tool
	end

#= switcher integration point

	def hotkey_action_switcher( params )
		event = params[:event]
		pe_debug "handling hotkey event. #{event.description} active app: #{NSWorkspace.sharedWorkspace.activeApplication}"
		
		if ! carouselling
			# this is the initial invocation
			self.toggle_main_window({ activation_type: :hotkey })
			else
			# this is a subsequent invocation
			self.select_next_tool
		end
		
		if activation_modifier_released?
			stop_carouselling
		end
	end

	def show_switcher
		@main_window_controller.browser_vc.load_switcher

		if activation_modifier_released?
			stop_carouselling
		end
	end
	
	def select_next_tool
		pe_log "select next tool"
		
		# tactical impl
		@main_window_controller.browser_vc.select_next_tool
		# NOTE strategic would be:
		# @switcher.select_next_tool
	end

	def load_selected_tool
		pe_log "load selected tool"
		
		@main_window_controller.browser_vc.load_selected_tool
	end

#= misc actions

	# work around situations where about panel is obscured by window.
	def handle_show_about(sender)
		NSApp.activateIgnoringOtherApps(true)
		NSApp.orderFrontStandardAboutPanel(sender)
	end

#= global error handling, app-specific.

	def on_load_error( e )
		debug e
		case e.message
		when 'history_empty'
			self.load_welcome_page
		end
	end

	#= TODO split all url-handling specific to url-handling.rb

#=
	
	def setup_gallery
		if default 'enable_gallery'
			react_to :main_window_shown do
				# main window to mirror viewer shown state.
				if self.main_window_shown
					@main_window_controller.window.frame = wc.window.frame
					# TODO move for better coverage of cases.
					self.activate_main_window
				else
					self.deactivate_main_window
				end
			end

			# work around the 2-way problem - next time we encounter this, adopt something like https://github.com/mruegenberg/objc-simple-bindings/blob/master/NSObject%2BSimpleBindings.m
			# on_main_async do
			# 	react_to 'main_window_controller.window.visible' do |visible|
			# 		if self.main_window_shown != visible
			# 			self.main_window_shown = visible
			# 		end
			# 	end
			# end
			# NOTE  20130911 this doesn't make sense - tis' chicken-egg vis-a-vis the above.
		else
			# TODO teardown.
		end
	end
end

		
class Hash
	def delete_value( val )
		self.keys.each do |key|
			if self[key] == val
				pe_log "deleting value #{val} from hash #{self.object_id}"
				self.delete key
			end
		end
	end
end

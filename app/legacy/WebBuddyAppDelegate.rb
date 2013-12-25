# require 'debugging'

# TODO finish factoring out all hotkey concerns.

class WebBuddyAppDelegate < PEAppDelegate
	include ServicesHandler
	include Preferences

	include ComponentClient

	include KVOMixin
	include Reactive


	# collaborators

	attr_reader :context_store

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
				module: BrowserDispatch,
			},
			{
				module: HotkeyHandler,
			},
			{
				module: WindowPreferenceExposer,
			},
			# {
			# 	module: ServicesHandler,
			# },
		].tap do | cs|
			# dev-only
			if RUBYMOTION_ENV == 'development'
				cs <<
					{
						module: HotloaderComponent,
					}
			end
		end
	end


#= major lifecycle

	def setup

		super

		# important domain object
		self.user = User.new

		# the app's domain model / storage scheme.
		self.setup_context_store

		setup_components

		# legacy defaults
		@intro_enabled = default :intro_enabled
		@load_welcome = default :load_welcome

		# deprecated / unused defaults
		# @show_toolbar_on_hotkey = default :show_toolbar_on_hotkey

		# experimental default-driven behaviour #REFACTOR
		@load_ext_url_policy = default :load_ext_url_policy

		if $DEBUG
			periodically do
				pe_log "mainWindow: #{NSApp.mainWindow}, keyWindow: #{NSApp.keyWindow}"
				pe_log "responder chain: #{NSApp.keyWindow.responder_chain}" if NSApp.keyWindow
			end
		end
	end

	def setup_part2
		super

		watch_notification :Activation_notification

		# user actions
		watch_notification :Visit_request_notification
		watch_notification :Revisit_request_notification
		watch_notification :Site_search_notification
		
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


	def setup_context_store
		try {
			@context_store = ContextStore.new
	
			if_enabled :load_context
	
			self.user.context = @context_store.current_context
		}
	end

	
#= IBActions for menu

	def handle_show_gallery( sender )
		## MAIN-WINDOW
		# self.main_window_shown = true
		
		wc.component(FilteringPlugin).show_plugin
	end

	def handle_hide_gallery( sender )
		## MAIN-WINDOW
		# self.main_window_shown = false

		wc.component(FilteringPlugin).hide_plugin
	end

	def toggle_front( sender )
		self.toggle_viewer_window
	end

#= intro

	def load_intro(sender = nil)
		wc.do_activate
		wc.window.center

		url = NSBundle.mainBundle.url 'plugin/intro/index.html'

		self.load_url url.absoluteString,
			interface_callback_handler: self

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
		# welcome_plugin_url = plugin(:welcome).url  # SKETCH plugin per static is too heavy. perhaps a statics plugin?
		welcome_plugin_url = NSBundle.mainBundle.url "plugin/welcome/index.html"
		
		self.load_url [ url, welcome_plugin_url ]
	end

	def load_url(urls, details = {})
		# debug [ urls, details ]
		wc = current_viewer_wc

		wc.do_activate.load_url urls, details
	end

#= activation / deactivation

	def deactivate_if_needed
		#		main_window.orderOut(self)

		visible_windows_in_space = self.visible_windows.select &:isOnActiveSpace
		pe_debug "visible windows on space: #{visible_windows_in_space}"

		if visible_windows_in_space.empty?
			NSApp.hide(self)
		end
	end

	def deactivate_on_resign
	  deactivate_viewer_window
	end
	

	# TODO delay until space state stabilises.
	def handle_Activation_notification( notification )
		NSApp.activate
		self.activate_viewer_window
	end

#= user actions
	
	def handle_Visit_request_notification( notification )
		new_location = notification.userInfo
		self.load_url new_location.to_url_string, stack_id: 'stub-visit-track'
	end
	
	def handle_Revisit_request_notification( notification )
		url = notification.userInfo.url
		self.load_url url, stack_id: notification.userInfo.stack_id
	end

	def handle_Site_search_notification(notification)
		pe_trace stack.format_backtrace.report
		
		search_details = notification.userInfo

		wc.do_activate.do_search search_details
	end

#= tracks

	def save_context
		@context_store.save
	end

	def load_context
		@context_store.load
	end
	
	def app_stack_id
		result = @current_app
		if ! result || result =~ /#{NSApp.name}/
			result = @previous_app
		end
		result
	end


	#= policies

	def load_ext_url_in_main_window( params )
		self.main_window_shown = true

		@main_window_controller.load_url params[:url]
	end

	# RENAME load_ext_url_in_viewer
	def load_ext_url_in_space_window( params )
		url = params[:url]

		self.current_viewer_wc.do_activate
		self.load_url url, stack_id:app_stack_id
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
		@main_window_controller.setup	context_store: @context_store

		@main_window_controller.stack = @context_store.current_context  # REDUNDANT

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
		self.current_viewer_wc
			.do_activate
			.show_toolbar
		

		self.update_main_window_state
	end

	def deactivate_viewer_window
		current_viewer_wc.do_deactivate -> {
			# return focus to previous app
			self.deactivate_if_needed
		}

		on_main_async do
			self.update_main_window_state
		end
	end
	
	def new_viewer_window_controller( initially_visible = false )
		pe_log "initialising a new viewer."

		current_space_id = @spaces_manager.current_space_id
		viewer_wc = nil

		trace_time 'viewer_wc init' do
			viewer_wc = ViewerWindowController.alloc.init
		end

		# only if same space.
		if current_space_id == @spaces_manager.current_space_id
			viewer_wc.window.visible = initially_visible
		else
			raise "space changed while creating new viewer_window_controller"
		end
		
		trace_time 'viewer_wc setup' do
			viewer_wc.setup context_store: @context_store
		end

		viewer_wc
	end


	def current_viewer_wc
		current_space_id = @spaces_manager.current_space_id
		viewer_wc = @viewer_controllers_by_space[current_space_id] if @viewer_controllers_by_space

		if viewer_wc.nil?
			# EDGECASE sometimes we end up not picking up the viewer_wc for the space - check for this case and rectify.
			viewer_wcs = @spaces_manager.windows_in_space
				.map(&:windowController)
				.select {|e| e.is_a? ViewerWindowController}

			unless viewer_wcs.empty?
				viewer_wc = viewer_wcs[0]

				viewer_wcs[1..-1].map do |redundant_wc|
					pe_warn "closing redundant wc #{reduncant_wc} for space #{current_space_id}"
					reduncant_wc.should_close = true
					redundant_wc.close
				end
			else
				viewer_wc = new_viewer_window_controller
			end

			( @viewer_controllers_by_space ||= {} )[current_space_id] = viewer_wc
		end

		# update the current context.
		@context_store.current_context = viewer_wc.stack

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
		if_enabled :save_context
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
			
			if_enabled :save_context

			if_enabled :deactivate_on_resign
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

				redundant_wc.close
				
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

		case to_sym item.tag
		when :menu_item_debug_console
			# REFACTOR pull up
			# disable the debug console menu item unless build conf == debug.
			return Environment.instance.isDebugBuild

		when :menu_item_toggle_main_window
			# update the menu item text.
			@toggle_menu_item.title = 
				if wc.window.visible
					wc.window.active? ? 'Hide' : 'Bring to Front'
				else
				  'Show'
				end

			return true

		when :menu_item_deactivate_on_resign
			item.state = default(:deactivate_on_resign) ? NSOnState : NSOffState
		end

		# by default, enable items.
		true
	end
	
	# the generic menu item handler.
	def handle_menu_item_select(sender)
		case to_sym sender.tag
		when :menu_item_deactivate_on_resign
			current_state = (sender.state == NSOnState)
			set_default :deactivate_on_resign, ! current_state
		else
			raise "nothing implemented for #{sender}, tag #{sender.tag}"
		end
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


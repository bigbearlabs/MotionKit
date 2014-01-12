# for BBLWebViewDelegate backwards compatibility after refactor.

class WebViewDelegate < BBLWebViewDelegate
end

class BrowserWindowController < NSWindowController
	include ComponentClient
	include SheetHandling

	include KVOMixin
	include DefaultsAccess
	
	include Reactive
	include IvarInjection

	# cover interface for BVC
	extend Delegating
	def_delegator :browser_vc, :eval_js
	

	# influenceables.
	attr_accessor :should_close

	# all the data. LEAKY
	attr_accessor :stack  
	attr_accessor :search_details

	# bindable data
	attr_accessor :title
	attr_accessor :url
	attr_accessor :window_title_mode

	# view-layer references
	attr_accessor :top_portion_frame

	attr_accessor :split_view
	attr_accessor :nav_buttons_view

	attr_accessor :overlay_window
	attr_accessor :overlay_frame

	# modules
	attr_accessor :browser_vc
	attr_accessor :progress_vc
	attr_accessor :input_field_vc
	attr_accessor :page_details_vc
	attr_accessor :bar_vc

	attr_accessor :plugin_vc

	def components
		[
			{
				module: InputHandler
			},
			{
				module: RubyEvalPlugin
			},
			{
				module: FilteringPlugin,
				deps: {
					context_store: @context_store
				}
			},
	  	{
	  		module: FindPlugin
	  	}
		]
	end
	

#= lifecycle

	def init
		self.initWithWindowNibName('MainWindow')

		# for an unknown reason this can't be set in ib.
		self.shouldCascadeWindows = false

		self
	end
	
	def awakeFromNib
		super
	end
	
	def setup(collaborators)    
		raise "no window for #{self}" unless self.window
				
		inject_collaborators collaborators

		setup_components

		# self.setup_tracking_region
		# self.setup_nav_long_click

		self.window_title_mode = :title

		@plugin_vc.setup( {} )			

		@browser_vc.setup context_store: @context_store

		pe_log "#{self} synchronous setup complete."

		# asynchronously set up the rest, for more responsive windows.
		on_main_async do

			# TODO extract stack-population related workflow like this into an appropriate abstraction.
			# populate model's redirections 
			@redir_reaction = react_to 'browser_vc.web_view_delegate.redirections' do |redirections|
				# just keep adding the current page - it should be enough.
				self.stack.add_redirect redirections[0], @browser_vc.web_view.url
			end

			@browser_vc.web_view.make_first_responder 

			# self.setup_overlay

			watch_notification :Load_request_notification, @browser_vc.web_view_delegate
			watch_notification :Title_received_notification, @browser_vc.web_view_delegate
			watch_notification :Url_load_finished_notification, @browser_vc.web_view_delegate
			# watch_notification :Link_navigation_notification, @browser_vc.web_view_delegate

			# user
			watch_notification :Bf_navigation_notification

			# input field
			self.setup_input_field

			# history views
			watch_notification :Item_selected_notification

			self.setup_reactive_title_bar
			self.setup_reactive_history_item_sync
			self.setup_responder_chain

			self.setup_actions_bar

			# MOTION-MIGRATION
			# @progress_vc.setup
			# self.setup_reactive_detail_input
			# self.setup_popover

		end
	end

	def setup_input_field
		@input_field_vc.setup

		watch_notification :Input_field_focused_notification, @input_field_vc
		watch_notification :Input_field_unfocused_notification, @input_field_vc
		watch_notification :Input_field_cancelled_notification, @input_field_vc

	end

	def setup_popover
		self.setup_reactive_first_responder
	end
			

	def setup_reactive_detail_input
		@reaction_detail_input = react_to 'browser_vc.web_view.mainFrameURL', :search_details, 'page_details_vc.display_mode' do
			on_main_async do
				self.refresh_page_detail if @page_details_vc
			end
		end
	end

	def setup_reactive_first_responder
		# when detail popover hidden, make webview first responder
		@reaction_first_responder = react_to 'page_details_vc.popover.shown' do
			on_main_async do
				if ! @page_details_vc.shown?
					self.browser_vc.web_view.make_first_responder
				end
			end
		end

		# update gallery_vc with responder chain membership status. TODO
		# NO attach key handler to wc and consult responder chaing instead.
	end

	def setup_actions_bar
		@bar_vc.setup

		watch_notification :Bar_item_selected_notification
		watch_notification :Bar_item_edit_notification
		watch_notification :Bar_item_delete_notification
	end

	def setup_reactive_title_bar
		react_to 'browser_vc.web_view_delegate.state' do |new_state|
			url = @browser_vc.web_view.url
			pe_log "state changed to #{new_state}. url: #{url}"
			self.title = @browser_vc.web_view_delegate.title
		end

		observe_kvo self, :title do |k,c, ctx|
			new_title = self.title
			new_title ||= '<no title>'  # guard against transient nil situations
			window.title = new_title if self.window_title_mode == :title
		end

		observe_kvo self, :url do |k, c, ctx|
			window.title = self.url if self.window_title_mode == :url     
		end

		# # MOTION-MIGRATION
		# # add a click handler in the region of the title,
		# # invoke page popover.
		# window.frame_view.track_mouse_down do |event, hit_view|
		#   # if event.locationInWindow.in_rect( window.frame_view._titleControlRect )  # MOTION-MIGRATION
		#   if NSPointInRect(event.locationInWindow, window.frame_view._titleControlRect )
		#     # handle_carousel_title self

		#     handle_toggle_page_detail self
		#   end
		# end
	end

	def setup_reactive_history_item_sync
		react_to 'browser_vc.web_view_delegate.state' do |new_state|
			# update the WebHistoryItem
			if new_state == :loaded
				self.stack.update_item @browser_vc.web_view_delegate.url, @browser_vc.current_history_item if self.stack
			end
		end
	end

	def handle_carousel_title( sender )
		self.window_title_mode = (self.window_title_mode == :title) ? :url : :title
		window.title =
			if self.window_title_mode == :title
				self.title
			else
				self.url
			end
	end


	def carousel_find( direction )
		@find_carousel ||= (
			elem1 = NamedProc.new :input_field do
				handle_focus_input_field self
				NSApp.delegate.handle_show_gallery self
			end
			elem2 = NamedProc.new :find_field do
				pe_log "TODO focus on find field"
				NSApp.delegate.handle_hide_gallery self
			end
			elem3 = NamedProc.new :page_search_field do
				pe_log "TODO focus on search field on page."
			end

			# Carousel.new [ elem1, elem2, elem3 ]
			# DISABLED work out exact behaviour spec

			Carousel.new [elem1, elem2]

			# TODO carousel state should be reset on key press, unfocus, potentially other events.
		)


		case direction
		when :next
			@find_carousel.next
		when :previous
			@find_carousel.previous
		end
	end
	
#= 

	def handle_show_location(sender)
		# self.page_details_vc.display_mode = :url
		# self.handle_show_page_detail self

		@input_field_vc.display_mode = :Display_url
		@input_field_vc.focus_input_field
	end

	def handle_show_search(sender)
		# self.page_details_vc.display_mode = :query
		# self.handle_show_page_detail self   

		@input_field_vc.display_mode = :Display_enquiry
		@input_field_vc.focus_input_field
	end


#= popover-specific

	def handle_toggle_page_detail(sender)
		if @page_details_vc.shown?
			@page_details_vc.hide_popover
		else
			self.handle_show_page_detail self
		end
	end

	def handle_show_page_detail(sender)
		# self.show_page_detail_popover
		# self.show_toolbar
	end

	def refresh_page_detail
		@page_details_vc.text_input = 
			case self.page_details_vc.display_mode
			when :query
				@search_details ? @search_details[:query] : ''
			else
				@browser_vc.web_view.url
			end
	end


	def show_page_detail_popover
		@page_details_vc.anchor_view = self.title_frame_view
		@page_details_vc.show_popover

		unless @page_details_vc_setup
			@page_details_vc.setup

			@page_details_vc.page_collection_vc.representedObject = self.stack

			@page_details_vc_setup = true
		end
	end

#=

	# a tracking region for the toolbar area.
	def setup_tracking_region
		rect_for_toolbar = NSMakeRect(0, @browser_vc.view.height, @browser_vc.view.width, window.frame.size.height - @browser_vc.view.height)

		window.frame_view.add_tracking_area rect_for_toolbar,
			-> {
				puts 'mouse entered toolbar rect'
			}, 
			-> {
				puts 'mouse exited toolbar_rect'
			}
	end
	
	def setup_nav_long_click
		class << @nav_buttons_view
			attr_accessor :target
		
			def mouseDown( event )
				if event.type == NSLeftMouseUp
					# called from the up event handler. do a click if threshold not breached
					if @down_time.seconds_since_now < @nav_click_delayed_execution.delay
						super
					end
				else
					pe_debug "nav down"

					@down_time = Time.new

					@nav_click_delayed_execution = DelayedExecution.new(0.5, proc {
						pe_debug "ding."
						@target.toggle_popover(self)
					})
				end
			end
		
			def mouseUp( event )
				pe_debug "nav up"

				@nav_click_delayed_execution.cancel
				
				# due to NSSegmentedControl idiosyncrasies, we must send the down event to super when the up event comes in, otherwise normal clicks don't work.
				super.mouseDown(event)
			end
		end
		@nav_buttons_view.target = self

	end

	# this is undesirable due to the unpredictable ways in which the responder chain can break. in order to add behaviour to the responder chain, we should instead use delegation from this class to collaborators.
	def setup_responder_chain
		pe_log "responder chain pre-setup: #{self.window.responder_chain}"
		

		# BrowserVC deals with validation of some important commands and scroll events
		self.window.insert_responder @browser_vc
		
		# web view should always be in responder chain
		# FIXME disabled due to responder-chain mangling anomaly when webview becomes first responder
		# self.window.insert_responder @browser_vc.web_view

		pe_log "responder chain post-setup: #{self.window.responder_chain}"
	end

	# TODO wire with a system menu handler
	# include MenuHandling
	def on_menu_item( item )
		case item_lookup[item.tag]
		when :url, :enquiry
			@input_field_vc.show :url  # TODO tidy up the old methods and get the menus to properly switch between display modes.
		else
			# what's the default?
		end
	end

#= input field
	
	# actions - the name is now lagging as these control the control overlay.
	
	def handle_hide_input_field(sender)
		self.input_field_shown = false
	end
	
	def handle_focus_input_field(sender)
		send_notification :Input_field_focused_notification

		self.input_field_shown = true

		@input_field_vc.focus_input_field
	end
	

	# view operations
		
	def hide_toolbar( delay = 0 )
		delayed_cancelling_previous delay, -> {
			on_main {
				@top_portion_frame.do_animate -> animator {
					animator.alphaValue = 0
				}, -> {
					@top_portion_frame.hidden = true
					@top_portion_frame.alphaValue = 1

					# some resizing / repositioning during the days when the browser view wasn't fixed.
					# @bar_vc.frame_view.snap_to_top
					# @browser_vc.frame_view.fit_to_bottom_of @bar_vc.frame_view
				}
			}
		}
	end

	# TODO there are cases where this doesn't render properly - implement the top-of-scroll-view solution.
	def show_toolbar
		on_main {
			@top_portion_frame.do_animate -> animator {
				animator.hidden = false

				# @bar_vc.frame_view.snap_to_bottom_of @input_field_vc.frame_view
				# @browser_vc.frame_view.fit_to_bottom_of @bar_vc.frame_view
			}

		}

	end
	
	def toolbar_shown?
		@top_portion_frame.visible
	end

	# events

	def handle_Input_field_focused_notification( notification )
		# self.show_popover(@nav_buttons_view)
	
		self.show_toolbar

		# disable the overlay for now.    
=begin
		case @input_field_vc.mode 
		when :Filter
			self.show_filter_overlay
		else
			self.show_navigation_overlay
		end
=end
	end

	def handle_Input_field_unfocused_notification( notification )
		# self.hide_overlay
	end
	
	def handle_Input_field_cancelled_notification( notification )
		# self.handle_transition_to_browser
		# self.hide_overlay
	end

#= REFACTOR to on_input.

	def handle_input( input, details = {})
		# just try loading, fall back to a search.
		self.load_url [input, input.to_search_url_string], details
	end
	
#= browsing

	#= interface

	# params:
	# objc_interface_obj: interface from js to webbuddy.
	# stack: the stack to add this page to.
	# stack_id: the id of stack if stack retrieval not suitable.
	# FIXME migrate objc_interface_obj to webbuddy.interface, migrate webbuddy.module use cases.
	def load_url(urls, details = {})
		sid = details[:stack_id]  # can be nil.
		self.stack = @context_store.stack_for( sid ) if sid

		@browser_vc.load_url urls, details

		component(FilteringPlugin).hide_plugin
	end

	#= browsing workflow

	def handle_Item_selected_notification( notification )
		NSApp.delegate.user.perform_stack_navigation( notification.userInfo )
	end
	
	def handle_Bf_navigation_notification( notification )
		if @overlay_window && ! self.overlay_shown?
			on_main {
				self.show_navigation_overlay
			}
		end
	end
	
	#= browsing lifecycle
	# TODO move out to a component.
	def handle_Load_request_notification( notification )
		new_url = notification.userInfo

		if_enabled :touch_stack, new_url, provisional: true

		# debug [ self.stack_id, notification ]

		## zoom to page
		# self.overlay_enabled = false
		# self.zoom_to_page new_url

		# TACTICAL
		# self.hide_gallery_view self
	end


	def handle_Title_received_notification( notification )
		# if mouse in overlay, postpone overlay hiding.
		delayed_cancelling_previous default(:overlay_dismissal_delay), -> {
			unless self.overlay_enabled || ! @overlay_window
				if @overlay_window.mouse_inside?
					@overlay_window.close_when_mouse_exits = true
				else
					self.hide_overlay
				end
			end

			@page_details_vc.hide_popover
		}
	end

	def handle_Url_load_finished_notification( notification )
		new_url = notification.userInfo

		# TODO observe thumbnails instead.

		@thumbnail = browser_vc.web_view.image

		if_enabled :touch_stack, new_url, 
			provisional: false,
			thumbnail: @thumbnail


		# TODO consider invoking update_item here.

		# PERF?
		( @update_throttle ||= Object.new ).delayed_cancelling_previous 0.5, -> { 
			# component(FilteringPlugin).update_data  # DEV
			@context_store.save_thumbnails
		}
	end
	
#= bar

	def handle_Bar_item_selected_notification( notification )
		# perform a site visit or search.
		site = notification.userInfo
		search_str = @input_field_vc.input_text
		
		pe_debug "site: #{site}, search_str:#{search_str}"
		
		if search_str.to_s.empty?
			NSApp.delegate.user.perform_url_input site.base_url
		else
			NSApp.delegate.user.perform_search search_str, site
		end
	end
	
	def handle_Bar_item_edit_notification( notification )
		self.handle_configure_site notification.userInfo
	end

	def handle_Bar_item_delete_notification( notification )
		self.delete_site notification.userInfo
	end

#= data management

	def touch_stack( url, details )
		if self.stack
			self.stack.touch url, details

			self.stack.update_detail @browser_vc.url, details
		else
			raise "#{self} has no stack. "
		end
	end

#== site configuration sheet
	## disabled until relationship between stacks and sites are made clearer.
	# def handle_add_site(sender)
	#   site = @context.new_site
	#   handle_configure_site site
	# end

	# def handle_configure_site(site) # RENAME not a handle_ method 
	#   @site_conf_controller ||= SiteConfigurationWindowController.alloc.init

	#   @site_conf_controller.site = site

	#   # present as sheet
	#   self.show_sheet @site_conf_controller do
	#     # when finished,

	#     @site_conf_controller.update_model
	#     @bar_vc.refresh
	#   end
	# end
	
	# def delete_site(site)
	#   # as a quick impl, just delete. sheet-based workflow depends on better modularisation of the platform-specific sheet handling.

	#   @context.remove_site site
	#   @bar_vc.refresh
	# end

#= sidebar
	
	def toggle_sidebar(sender)
		if sidebar_displayed
			@split_view.collapse_view_at 0
		else
			@split_view.uncollapse_view_at 0
		end
	end
	
	def sidebar_displayed
		! @split_view.isSubviewCollapsed( @split_view.subviews[0] )
	end
	
	# splitview delegate methods
	
	def splitView( splitView, canCollapseSubview:subview )
		true
	end
	
	def splitView( splitView, constrainMaxCoordinate:proposedMax, ofSubviewAt:dividerIndex )
		if dividerIndex == 0
			#splitView.subviews[dividerIndex].height
			0
		else
			proposedMax
		end
	end

#= browser activity control

	def handle_refresh(sender)
		@browser_vc.handle_refresh sender
		@progress_vc.loading = true
	end

	def handle_stop(sender)
		@browser_vc.handle_stop sender
		@progress_vc.loading = false
	end
	
#= window behaviour
	
	def do_activate( completion_proc = -> {} )
		# debug
		case default(:activation_style)
		when :popover
			status_bar_window = NSApp.windows.select {|w| w.is_a? NSStatusBarWindow } [0]
			@window_page_details_vc.show_popover status_bar_window.contentView

			# REFACTOR move out to a policy implementation.
		else
			
			self.window.do_activate -> {
				NSApp.activate

				completion_proc.call
			}

		end

		self
	end

	def do_deactivate( completion_proc = -> {} )
		case default(:activation_style)
		when :popover
			@window_page_details_vc.hide_popover
		else
			@page_details_vc.hide_popover
			self.window.do_deactivate completion_proc
		end

		self
	end

	def do_hide
		# first hide the window to prevent flickering
		self.window.orderOut(self)

		self
	end

	#= NSWindowDelegate

	def windowShouldClose( window )
		# deactivate instead.
		window.do_deactivate
		
		@should_close
	end
		
	def windowDidBecomeKey( notification )
		pe_debug 'main window became key.'
		
		## we have various attempts to control window foregrounding behaviour littered here. CLEANUP

		#self.setLevel( KCGFloatingWindowLevel )
			
		# NSApp.activateIgnoringOtherApps( true )
			
		# extra strong measures to avoid 'key but not active' situation when switching spaces.
		# self.orderFrontRegardless
			
		# self.orderWindow( NSWindowAbove, relativeTo:0 )
			
		#@mask_window.set_view_to_transparent
		#@mask_window.makeMainWindow
		#@mask_window.orderFront(self)
			
		pe_debug "main window delegate: #{self.window.delegate}"

		# ensure browser view controller in responder chain so as to handle swipes, and react if any anomalies.
=begin
		unless self.window.responder_chain.include? @browser_vc
			pe_warn "browser view controller #{@browser_vc} escaped the responder chain #{self.window.responder_chain} for #{self}'s window"
			debug [ self.window, @browser_vc ]
			self.window.insert_responder @browser_vc
		end
=end
				
		# drop the anchor.
		# @space_anchor_window.orderFrontRegardless
		# @space_anchor_window.setFrameOrigin(self.frame.origin)
		# disabled until space-aware context switching re-enabled.
	end

	def windowDidResignKey( notification )
		pe_debug 'main window resigned key.'
		#self.setLevel( KCGNormalWindowLevel )
			
		# HUD panel defaults to floating level, so set to normal.
		self.window.level = KCGNormalWindowLevel
			
		# NSApp.deactivate

		# disabled until space-aware context switching re-enabled.
		# hoist the anchor.
		# @space_anchor_window.orderOut(self)
	end
	
	def windowWillResize(window, toSize:size)
		@overlay_window.resize_to_parent_frame if @overlay_window
		self.window.resize_mask_window
		
		size
	end
	
	def windowDidEndLiveResize( notification )
		@overlay_window.resize_to_parent_frame if @overlay_window
		self.window.resize_mask_window
	end
	

#= quickly test core animation basics
	def kaboom
		@original_view = @main_window_controller.window.view
		
		new_view = NSView.alloc.initWithFrame(@main_window_controller.window.frame)
		@main_window_controller.window.view = new_view
		new_view.layer = CALayer.layer
		new_view.wantsLayer = true
		
		image = @original_view.image
		sublayer = CALayer.layer
		sublayer.contents = image
		sublayer.frame = new_view.frame
		new_view.layer.addSublayer(sublayer)
		new_view.layer.setNeedsDisplay
	end

	def last_url
		unless self.stack.pages.last
			raise 'history_empty'
		end

		self.stack.pages.last.url
	end

## would like to factor shit out like this but will it cause startup performance issues?


#= overlay

	attr_accessor :overlay_enabled    # temporary display logic sets this to false, then certain events (eg nav) will dismiss the overlay.
	
	def setup_overlay
		# init overlay window
		history_view = history_vc.view

		history_vc.layout_horizontal
		
		@overlay_window = OverlayWindow.alloc.initWithView(history_view, attachedToPoint:self.overlay_top_middle, inWindow:self.window, onSide:NSMinYEdge, atDistance:0)
		@overlay_window.hasArrow = NSOffState
		
		@overlay_window.releasedWhenClosed = false
		
		# show and hide to really hide.
		self.hide_overlay

		# track mouse entry
		@overlay_window.contentView.add_tracking_area -> view {
				pe_debug "mouse entered #{view}"
			}, 
			-> view {
				pe_debug "mouse exited #{view}"
				if @overlay_window.close_when_mouse_exits
					self.hide_overlay
					@overlay_window.close_when_mouse_exits = false
				end
			}
			
	end
	
	def show_filter_overlay
		self.overlay_enabled = false
		self.show_overlay if toolbar_shown?
	end
	
	def show_navigation_overlay
		self.overlay_enabled = false
		self.show_overlay if toolbar_shown?
	end
	
	def show_overlay
		self.resize_overlay
		
		@overlay_window.isVisible = true
		NSAnimationContext.beginGrouping
		@overlay_window.animator.alphaValue = 1
		NSAnimationContext.endGrouping
	end

	def hide_overlay
		# @overlay_window.isVisible = false
		NSAnimationContext.beginGrouping
		@overlay_window.do_animate -> animator { 
			animator.alphaValue = 0 
		},
			-> { @overlay_window.isVisible = false }
		NSAnimationContext.endGrouping
		
		self.overlay_enabled = false
		
	end

	def resize_overlay
		self.window.addChildWindow(@overlay_window, ordered:NSWindowAbove)
		@overlay_window.resize_to_parent_frame
	end
	
	def overlay_shown?
		@overlay_window && @overlay_window.alphaValue == 1
	end
	
	def overlay_top_middle
		point = @overlay_frame.frame.top_and_middle
		# @overlay_frame.convertPoint(point, toView:nil)
	end
end
	
# this class needed because singleton method doesn't seem to work reliably with NSWindow subclasses. but why?

# class << @overlay_window
#   def canBecomeKeyWindow
#     false
#   end
# end

# MOTION-MIGRATION
# class OverlayWindow < MAAttachedWindow
#   attr_accessor :close_when_mouse_exits
			
#   def canBecomeKeyWindow
#     false
#   end
	
#   def resize_to_parent_frame
#     if self.parentWindow
#       top_and_middle = self.parentWindow.delegate.overlay_top_middle
#       # overlay_center = NSMakePoint( top_and_middle.x, top_and_middle.y - (self.frame.height / 2 ) )
#       self.setPoint(top_and_middle, side:NSMinYEdge)

#       width_adjusted_frame = self.frame.modified_frame_horizontal(self.parentWindow.delegate.overlay_frame.bounds.width)
#       self.frame = width_adjusted_frame
						
#       self.contentView.update_tracking_areas
#     end
#   end

# end



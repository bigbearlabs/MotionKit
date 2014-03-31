# motion_require 'BrowserWindowController'

# a Viewer is used for all links originating from other apps.
class ViewerWindowController < BrowserWindowController

	def init
		super

		self.window.collectionBehavior = 
			NSWindowCollectionBehaviorDefault|
			NSWindowCollectionBehaviorManaged|
			NSWindowCollectionBehaviorParticipatesInCycle

		self
	end

	def setup(collaborators)
		super

		react_to :bar_shown do |shown|
			if shown
				self.show_toolbar
			else
				self.hide_toolbar
			end
		end
		
		setup_reactive_refresh_bar

		setup_reactive_update_thumbnail


		begin
			on_setup_complete
		rescue => e
			# case: first-time launch
			# case: etc etc

			NSApp.delegate.on_load_error e
		end

	end

	# TODO browser_view.event
	# TODO revise mouse tracking routines to interface via .mouse_entered
	def setup_reactive_refresh_bar
	  self.title_bar_view.track_mouse_entered
	  react_to 'title_bar_view.mouse_entered' do |entered|
	  	if entered
	  		self.bar_shown = true

	  		# react to mouse out of the wider tracking area TODO
	  	else
	  		# self.hide_toolbar delay:2
	  	end
	  end

	  react_to 'browser_vc.web_view.scroll_event' do |event|
	  	if event
	  		self.bar_shown = false
	  	end
	  end
	end
	
	def setup_reactive_update_thumbnail
	  react_to 'browser_vc.web_view.scroll_event' do |event|
	  	# using a small delay, attach a thumbnail for the history item for the swipe handler to use to to animate paging.
	  	(@thumbnail_throttle ||= Object.new).delayed_cancelling_previous 0.1, -> {
	  		pe_log "taking thumbnail after scroll event #{event}"
	  		@browser_vc.snapshot
	  	}
	  end

	end
	

	#= gallery

	# include CollectionGallery

	#= view

	def handle_transition_to_browser
		url = @browser_vc.url
		self.zoom_to_page url
	end

	def show_browser_view
		# @browser_vc.view.visible = true
		@gallery_view_frame.visible = false
	end

end


# isolate concerns for filtering, input field.
class MainWindowController < BrowserWindowController
	# bindable
	attr_accessor :input_field_shown


# MOTION-MIGRATION
 #  include CollectionGallery

	# def setup
	# 	super

	# 	# in order to work with the main-async routine in super, these need dispatching too.
	# 	# on_main_async do
	# 	# 	if self.class.ancestors.include? CollectionGallery
	# 	# 		self.setup_gallery
	# 	# 		self.show_gallery_view self
	# 	# 	end
	# 	# end
	# end
	
	def components
		super + [
			{
				module: InputFieldComponent,
				deps: {
					input_field_vc: @input_field_vc
				}
			},
			{
				module: FilteringPlugin,
				deps: {
					context_store: @context_store
				}
			},
			{
				module: RubyEvalPlugin
			},
		]
	end
	

	def setup(collaborators)
		# show in all spaces but hide on new space by default.
		self.window.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace

		# ensure outlets all set.
		self.window.show

		setup_default_keys :input_field_vc, :plugin_vc

		# secondary collaborators
		@plugin_vc.setup context_store: 'stub-context-store'


	  super
		
	  # view state
	  @input_field_vc.frame_view.visible = true

		# reactively show filtering plugin.
		react_to 'input_field_vc.input_field_focused' do |focused|
			if focused
				component(FilteringPlugin).show_plugin
			end
		end

		# reactively forcus / hide input field.
		react_to_and_init :activation_type do |val|
			if val == :hotkey		# initial view state
				self.handle_focus_input_field(self)
			else
				self.handle_hide_input_field(self)
			end
		end

	end

	def load_url(urls, details = {})
		super

		component(FilteringPlugin).hide_plugin
	end


	def filter( filter_spec )
		# gallery_vc.update_filter_spec filter_spec
	end
	
	#= input field

	# OBSOLETE
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

end


#= relocate.

class NSWindowController

	def title_bar_view
		top_level_view = self.window.view.superview
		if ! @title_bar_view
			@title_bar_view = new_view top_level_view.titlebarRect
			top_level_view.addSubview(@title_bar_view)
		else
			@title_bar_view.frame = top_level_view.titlebarRect	  	
		end

		@title_bar_view
	end
	
end

class NSView
	
	attr_accessor :mouse_entered  # true when mouse comes in.

	def track_mouse_entered
		self.add_tracking_area -> view {
				self.mouse_entered = true
			}, 
			-> view {
				self.mouse_entered = false
			}
	end

end



# motion_require 'BrowserWindowController'

# a Viewer is used for all links originating from other apps.
class ViewerWindowController < BrowserWindowController

	# bindable
	attr_accessor :input_field_shown

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

		on_main_async do

			react_to :bar_shown do |shown|
				if shown
					self.show_toolbar
				else
					self.hide_toolbar
				end
			end
			

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

				# using a small delay, attach a thumbnail for the history item for the swipe handler to use to to animate paging.
				(@thumbnail_throttle ||= Object.new).delayed_cancelling_previous 0.1, -> {
					pe_log "taking thumbnail after scroll event #{event}"
					@browser_vc.snapshot
				}
			end
		end

		on_main_async do
			begin
				on_setup_complete
			rescue Exception => e
				# case: first-time launch
				# case: etc etc

				NSApp.delegate.on_load_error e
			end
		end
	end

	# TODO browser_view.event
	# TODO revise mouse tracking routines to interface via .mouse_entered

	def on_setup_complete
		# # load stack.
		# if self.stack
		# 	self.load_url last_url
		# else
		# 	"no stack, not loading."
		# end

		# # show filtering.
		# if browser_vc.url.nil?
		# 	self.component(FilteringPlugin).show_plugin
		# end

		# show initial.
		if browser_vc.url.nil?
			self.load_url default(:initial_url), stack_id: self.to_s
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


class MainWindowController < BrowserWindowController
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
	
	def filter( filter_spec )
		# gallery_vc.update_filter_spec filter_spec
	end
	
end

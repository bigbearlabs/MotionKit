# require 'CocoaHelper'
# require 'KVOMixin'
# require 'NotificationCenterHandling'
# require 'reactive'

# macruby_framework 'WebKit'

class BrowserViewController < PEViewController
	include ComponentClient

	include KVOMixin
	include Reactive
	include IvarInjection

	include DefaultsAccess
	include JsEval
	
	attr_accessor :web_view
	attr_accessor :nav_buttons_toolbar_item
	attr_accessor :nav_buttons
	
	attr_accessor :find_bar_container
	attr_accessor :swipe_handler
	
	attr_accessor :web_view_delegate
	
	# view-model
	attr_accessor :event  # last user-facing user agent event.

	def components
	  [
	  	{
	  		module: WebViewController,
			  deps: {
					web_view: @web_view
				},
	  	},
	  ]
	end


	def defaults_root_key
		'ViewerWindowController.browser_vc'
	end


	def init_state
	end
	
	def awakeFromNib
		super
		
		# UGH this only works with trackpads - not with magic mouse.
		# if @web_view
		# 	class << @web_view
		# 		def touchesBeganWithEvent(event)
		# 			pe_log "#{event}"
		# 		end
		# 		def touchesMovedWithEvent(event)
		# 			pe_log "#{event}"
		# 		end
		# 		def touchesEndedWithEvent(event)
		# 			pe_log "#{event}"
		# 		end
		# 		def touchesCancelledWithEvent(event)
		# 			pe_log "#{event}"
		# 		end
		# 	end
		# 	@web_view.acceptsTouchEvents = true
		# end

	end
	
	def setup( collaborators)
		super()
										
		inject_collaborators collaborators

		setup_components

		web_history = WebHistory.alloc.init
		WebHistory.setOptionalSharedHistory( web_history )
		
		# set own pref id to work around 'define..' bug
		@web_view.preferencesIdentifier = 'WebBuddy_web_view_preferences'
		
		@web_view.setApplicationNameForUserAgent( default(:user_agent_string) )
		
		# just a name to group all the frames.
		@web_view.setGroupName("singleton_web_view")
		
		@web_view.setMaintainsBackForwardList( true )
		
		# # when webview becomes first responder, it weirdly takes the window out of the responder chain. since this breaks hovers on dom elements, insert it back in the chain.
		# class << @web_view
		#   def becomeFirstResponder
		#     result = super
		#     
		#     @web_view.insert_responder @web_view.window unless @web_view.window.responder_chain.include? @webview.window
		#     pe_log "responder chain on webview firstresponder: #{@web_view.window.responder_chain}"
		#     
		#     result
		#   end
		# end

		# work around responder chain loss
		# @web_view.insert_responder @web_view.window
		
		# @w = Watcher.new( -> obj, change, ctx { puts "bflist.currentitem", obj, change } )
		# @w.watch @web_view, 'backForwardList.currentItem'
		
		# prevent inexplicable bflist collection
		# @bflist = @web_view.backForwardList
		
		@web_view_delegate.setup
		
		watch_notification :Find_request_notification
		watch_notification :Text_finder_notification
		watch_notification :Url_load_finished_notification
					
		self.setup_text_finder
		
		# self.setup_switcher

		# self.setup_nav_buttons_validation
	end
	
	def setup_nav_buttons_validation
		class << @nav_buttons_toolbar_item
			attr_accessor :p
			def validate
				p.call
			end
		end

		@nav_buttons_toolbar_item.p = proc {
			@nav_buttons.setEnabled(@web_view.canGoBack, forSegment:0)
			@nav_buttons.setEnabled(@web_view.canGoForward, forSegment:1)
		}
	end
	
#=

	def load_url(url_or_array, options = {})
    pe_trace

		load_handler = options[:success_handler]
		load_proc = proc {

			# MOVE
			# if (! options[:ignore_history]) && self.history_stack.item_for_url(new_url)
			# 		pe_log "load #{new_url} from history"
			# 		self.load_history_item self.history_stack.item_for_url new_url
			# else
			# 	@web_view.mainFrameURL = new_url
			# end

			# TODO prioritising the cache for loads may result in undesirable behaviour for certain cases - allow callers to optionally specify a fresh load.

			self.component(WebViewController).load_url url_or_array, options
		}

		# invoke proc in the appropriate fashion depending on whether wiring has finished.
		if self.web_view
			load_proc.call
		else
			react_to :web_view do
				on_main_async do
					load_proc.call if self.web_view
				end
			end
		end
	end
	
#=
	def handle_Url_load_finished_notification(notif)
		# handle_load_success notif.userInfo
	end
	
#=

	def handle_refresh( sender )
		@web_view.reload( sender )
	end
	
	def handle_stop( sender )
		@web_view.stopLoading(sender )
	end

#=

	protected

	def load_history_item(item_container)
		on_main {
			if ! @web_view.backForwardList.containsItem(item_container.history_item)
				pe_log "#{item_container.description} not found in bflist - was the backForwardList populated properly?"
				# load the location rather than use the bflist.
				@web_view.mainFrameURL = item_container.url
			else 
				pe_debug "loading history item #{item_container.url}"
				@web_view.stopLoading(self)
				@web_view.goToBackForwardItem(item_container.history_item)
				
				item_container.last_accessed_timestamp = Time.new.to_s
				
				unless @web_view.backForwardList.containsItem(item_container.history_item)
					pe_warn "#{item_container.description} not found in bflist - investigate."
				end
			end
		}
	end
	
	public

	def handle_back_forward(sender)
		back_forward_control = sender
		selected_segment = back_forward_control.selectedSegment
		case selected_segment
		when 0
			self.handle_back(self)
		when 1
			self.handle_forward(self)
		else
			raise "invalid case for back/forward navigation"
		end
	end
	
	def handle_back(sender)
		send_notification :Bf_navigation_notification

		on_main {
			@web_view.goBack(sender)
		}
	end
	
	def handle_forward(sender)
		send_notification :Bf_navigation_notification

		on_main {
			@web_view.goForward(sender)
		}
	end
	
#= 
	
	def policy_error_prompt_action( params )
		url = params[:url]

		self.show_dialog({
			message: "Oops, this is embarrasing - I'm so new I don't know how to handle this url yet.\n\nShall I send the URL '#{url}' to the main browser?",
			confirm_handler: proc {
				policy_error_send_to_primary params
			}
		})
	end

	def policy_error_send_to_primary( params )
		url = params[:url]
		pe_warn "TODO send #{url} to the browser"
	end

#=

	def makeTextLarger(sender)
		@web_view.makeTextLarger(sender)
	end
	
	def makeTextSmaller(sender)
		@web_view.makeTextSmaller(sender)
	end

#=

	def handle_pin(sender)
		history_item = @web_view.backForwardList.currentItem
		history_item.pinned = ! history_item.pinned
		#		self.history_stack.handle_pinning history_item
	end
	
#=

	# MOVE to BrowserDispatch.
	def handle_open_url_in( params = { role: :primary_browser } )
		role = params[:role]

		if role
			browser_bundle_id = self.bundle_id_for role
		end

		browser_bundle_id ||= params[:bundle_id]

		NSApp.delegate.component(BrowserDispatch).open_browser browser_bundle_id, self.url

		# NSApp.hide(self)  # a bit abrupt.
		self.view.window.windowController.do_deactivate
	end
	
	def bundle_id_for( role )
		case role
		when :primary_browser
			# read from defaults, return first.
			# STUB
			"com.apple.safari"
		end
	end
	
#=
	
	# FIXME kvo!
	def url
		@web_view.mainFrameURL
	end
	
	def current_history_item
		@web_view.backForwardList.currentItem
	end
	
	def back_page_image
		self.history_stack.back_item ? self.history_stack.back_item.thumbnail : NSImage.stub_image
	end

	def current_page_image
		self.history_stack.current_item ? self.history_stack.current_history_item.thumbnail : NSImage.stub_image
	end

	def forward_page_image
		self.history_stack.forward_item ? self.history_stack.forward_item.thumbnail : NSImage.stub_image
	end

#=

	def bf_report
			report = []
			
			if @web_view.backForwardList
				report << "current: #{@web_view.backForwardList.currentItem ? @web_view.backForwardList.currentItem.to_s + ',' + @web_view.backForwardList.currentItem.URLString : 'none'}"
				report << "back: #{@web_view.backForwardList.backItem ? @web_view.backForwardList.backItem.to_s + ',' + @web_view.backForwardList.backItem.URLString : 'none'}"
			else
				report "bflist currently nil."
			end
			
			report
	end
	

#= ui validation
	
	def validateUserInterfaceItem(item)
		# as back/forward buttons on toolbar is implemented with an NSSegmentedControl, this validation is only for menu items
		enabled = 
			case item.title
			when 'Back'	# I8N
				@web_view.canGoBack
			when 'Forward'
				@web_view.canGoForward
			else
				pe_log "validation of #{item} not implemented. returning true"
				true
			end
		return enabled
	end

#= trail integration (unused)

	def handle_path_control_click(sender)
		selected_cell = sender.clickedPathComponentCell
		@web_view.goToBackForwardItem( selected_cell.historyItem )
	end
	
#= gesture handling integration

	def setup_swipe_handler
		@animation_overlay = NSView.alloc.initWithFrame(self.view.bounds)
	end

	def wantsScrollEventsForSwipeTrackingOnAxis( axis )
		axis == NSEventGestureAxisHorizontal
	end

	def scrollWheel( event )
		pe_debug "#{event.description}"
		
		@swipe_handler.handle_scroll_event event
		super
	end

	#= 

	# work around the occasional respondsToSelector malfunction.
	def respondsToSelector(sel)
	  self.respond_to? sel
	end	


	protected

	def history_stack
	  @context_store.history_stack
	end
	
end


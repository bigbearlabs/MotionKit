# require 'CocoaHelper'
# require 'KVOMixin'
# require 'NotificationCenterHandling'
# require 'reactive'

# macruby_framework 'WebKit'

class BrowserViewController < PEViewController
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
	
	attr_accessor :input_field_vc    # used by web_view_delegate. messy but will be chunky to clean up.
	attr_accessor :web_view_delegate
	
	# view-model
	attr_accessor :event  # last user-facing user agent event.

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

	# def load_module( module_name, on_load = proc {})
	# 	modules_src = "#{NSApp.resource_dir}/modules/"
	# 	modules_tgt = "#{NSApp.app_support_dir}/modules"

	# 	# HACK copy modules to app support dir.
	# 	system "rsync -av '#{modules_src}' '#{modules_tgt}'"

	# 	url_str = "#{modules_tgt}/#{module_name}/index.html"

	# 	self.load_location url_str, on_load

	# 	# work around some weird caching behaviour by queuing a refresh.
	# 	delayed 0.5, proc {
	# 		on_main_async do
	# 			self.handle_refresh self
	# 		end
	# 	}
	# end
			
#=

#=

	def load_location(new_url, load_handler = nil, options = {})
		load_proc = proc {
			pe_debug "loading location #{new_url}"
			
			if new_url.is_a? NSURL
				new_url = new_url.absoluteString
			else
				new_url = new_url.to_url_string
			end
			
			if load_handler
				pe_log "dropping previous load handler" if @load_handler
				@load_handler = load_handler
			end
			
			if (! options[:ignore_history]) && (@context.history_contains_url new_url)
					pe_log "load #{new_url} from history"
					self.load_history_item @context.item_for_url new_url
			else
				@web_view.mainFrameURL = new_url
			end

			# TODO prioritising the cache for loads may result in undesirable behaviour for certain cases - allow callers to optionally specify a fresh load.
		}

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
		handle_load_success notif.userInfo
	end
	
	def handle_load_success( url )
		if url.is_a? NSString
			url = url.to_url
		end

		# invoke load handler.
		if @load_handler
			pe_log "calling success handler #{@load_handler} for #{url.absoluteString}"
			@load_handler.call

			# remove the handler.
			@load_handler = nil
		else
			pe_debug "no load handler for #{url.absoluteString}"
		end
	end

	# TODO wire up
	def handle_load_failure( url )
		# remove the handler.
		@load_handler = nil
	end

#=

	def handle_refresh( sender )
		@web_view.reload( sender )
	end
	
	def handle_stop( sender )
		@web_view.stopLoading(sender )
	end

#=

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
				
				item_container.last_accessed_timestamp = NSDate.date
				
				unless @web_view.backForwardList.containsItem(item_container.history_item)
					pe_warn "#{item_container.description} not found in bflist - investigate."
				end
			end
		}
	end
	
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
		#		@context.handle_pinning history_item
	end
	
#= find

	# invokes a js snippet that finds the text.
	def handle_Find_request_notification(notification)
		input_string = notification.userInfo

		self.find_string input_string
	end
	
	# API-compliant version of an in-page find.
	# issues: snatches first responder status
	def find_string( string )
		first_responder = self.view.window.firstResponder
		@web_view.searchFor(string, direction:(@find_direction != :back), caseSensitive:false, wrap:true)
		first_responder.make_first_responder
	end

	# js version using window.find
	def find_string( string )
		js = "window.find('#{string}')"
		self.eval_js js # TODO how to consolidate all js like this?
	end

	# js version with jquery
	def find_string( string )
		js = "jQuery.searchText($(), '#{string}', $('body'), null)"
		self.eval_js js
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
		@context.back_item ? @context.back_item.thumbnail : NSImage.stub_image
	end

	def current_page_image
		@context.current_history_item ? @context.current_history_item.thumbnail : NSImage.stub_image
	end

	def forward_page_image
		@context.forward_item ? @context.forward_item.thumbnail : NSImage.stub_image
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
	
#= the 10.7 standard find mechanism

	def setup_text_finder
		@text_finder ||= NSTextFinder.alloc.init
		@text_finder.client = self
		@text_finder.incrementalSearchingEnabled = true
		
		@text_finder.findBarContainer = @find_bar_container
		observe_kvo @find_bar_container, :findBarVisible do |obj, change, context|
			@action_type = nil # duped, ugh.
			
			pe_log "TODO clear search highlights"
			
			self.refresh_find_bar_container
		end
		
		self.refresh_find_bar_container
	end

	def handle_Text_finder_notification(notification)
		sender = notification.userInfo
		tag = sender.tag
		
		pe_log "tag from #{sender}: #{tag}"
		
		@text_finder.performAction(tag)
		
		# based on the tag, instruct webview to perform the right kind of search.
		case tag
		when NSTextFinderActionShowFindInterface
			pe_log "show interface"
			@action_type = :start_find
			
			self.load_js_lib
			
			self.refresh_find_bar_container

		when NSTextFinderActionNextMatch
			pe_log "next match"
			@action_type = :next_match
			
			string = @text_finder.search_field.stringValue
			self.find_string string
			
		when NSTextFinderActionPreviousMatch
			pe_log "previous match"
			@action_type = :previous_match
			
			string = @text_finder.search_field.stringValue
			self.find_string string
			
		when NSTextFinderActionHideFindInterface
			pe_log "hide interface"
			@action_type = nil

			self.refresh_find_bar_container
		end
	end

#= NSTextFinder

	def string
		pe_log "string request"
		search_content = self.eval_js 'document.documentElement.innerText'
	end

	# this is the hook that triggers incremental search
	def contentViewAtIndex(index, effectiveCharacterRange:range)
		
		pe_log "view request; #{index}, #{range[0].location}, #{range[0].length}"
		
		if ! @action_type
			pe_log "TODO clear search highlights"
		else
			#incremental search -
			# trigger the find in the webview. 
			@text_finder_field ||= @text_finder.search_field
			string = @text_finder_field.stringValue # PVT-API
			self.find_string string 
		end
		
		self.view
	end

	def rectsForCharacterRange(range)
		pe_log "rect reqeust"
		[ NSZeroRect ]
	end

=begin # this stuff unnecessary unless frames come in and make things ugly.
	def stringAtIndex(index, effectiveRange:range, endsWithSearchBoundary:outFlag)
		pe_debug "DING"
		
		str = self.string
		range.assign( NSMakeRange(0, str.length) )
		str
	end

	def stringLength
								 pe_debug "length DING"
		self.string.length
	end
=end

# TODO golden way to implement incremental find is to supply the rects for the matches. if this turns out to be infeasible due to webview api shortcomings, we should observe incrementalMatchRanges to detect incremental search progress, and eval the js.

=begin
	def firstSelectedRange
		# docs suggest this is needed for text finder-based 'find next' operation to work.
		# plan to use text finder may go tits up if we can't get the range of the selection in webview.
		pe_log "firstSelectedRange"
	end
=end
	
	def cancelOperation( sender )
		pe_debug "cancel find bar"
		
		@find_bar_container.findBarVisible = false
	end
	
	def refresh_find_bar_container
		if ! @action_type
			@find_bar_container.visible = false
			@web_view.frameSize = self.view.frameSize
		else
			@find_bar_container.visible = true
			@find_bar_container.frame = @find_bar_container.frame.modified_frame(find_bar_container.findBarView.frameSize.height + 1, :Top )

			@web_view.frame = @web_view.frame.modified_frame( self.view.frameSize.height - @find_bar_container.frameSize.height - 1, :Bottom )
		end
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
	
end

#=

class NSTextFinder
	def search_field
		findBarContainer.findBarView.views_where {|v| v.kind_of? NSFindPatternSearchField }.flatten.first
	end
end


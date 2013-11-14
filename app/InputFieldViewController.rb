#
#  InputFieldViewController.rb
#  WebBuddy
#
#  Created by Park Andy on 13/10/2011.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#

require 'cgi'
require 'uri'

require 'pemacrubyinfra/CocoaHelper'
require 'appkit_additions'
require 'KVOMixin'
require 'defaults'

Display_tags_by_modes = { 
	Display_enquiry: 7001, 
	Display_url: 7002, 
	Display_filter: 7003 
}


# REFACTOR reorganise members.
# RENAME morphing into a toolbar controller.
class InputFieldViewController < PE_NSViewController
	include KVOMixin
	include DefaultsAccess
	
	attr_accessor :input_field
	attr_accessor :input_field_hit_box
	
	attr_accessor :input_field_menu
	
	# unused.
	attr_accessor :url_button
	attr_accessor :google_button
	
	# UI model portion
	attr_accessor :current_enquiry
	attr_accessor :current_url
	attr_accessor :current_filter
	attr_accessor :input_text
	
	# for view bindings
	attr_accessor :display_string
	attr_accessor :enquiry_display_string
	attr_accessor :url_display_string
	attr_accessor :filter_display_string
	
	# association to domain
	attr_accessor :user
	
	# defaults
	attr_accessor :filter_delay
	attr_accessor :selection_handling_behaviour
	Display_modes = [ :Display_enquiry, :Display_url, :Display_filter ]
	attr_accessor :display_mode # what's the input field supposed to display?
	attr_accessor :submit_on_activation

	def setup
		super
		
		if self.view
			self.setup_text_field_click_handling
			
			self.setup_kvo_display_mode
			self.setup_kvo_display_strings
			self.setup_kvo_tracks

			observe_notification :Activation_notification
			observe_notification :Site_search_notification
			observe_notification :Visit_request_notification

			self.refresh_input_field
		end

		# TODO update current filter or enquiry on view spec update notification.
		
	end
	
	# unused
	def setup_text_field_click_handling
		# w = self.view.window
		# w.add_handler @input_field_hit_box, proc { |view|
		#   self.handle_focus_input_field(self)
		# }
	
		self.input_field.track_mouse_click do |event, view|
			qb_debug "clicked: #{event}"
			if view
				send_notification :Input_field_focused_notification
			end
		end
	end
	
	def setup_kvo_display_strings 
		observe_kvo self, :current_enquiry do |obj, change, ctx|
			self.enquiry_display_string = "Enquiry: #{self.current_enquiry}"
			self.refresh_menu
		end
		observe_kvo self, :current_url do |obj, change, ctx|
			self.url_display_string = "Address: #{self.current_url}"
			self.refresh_menu
		end
		observe_kvo self, :current_filter do |obj, change, ctx|
			self.filter_display_string = "Filter: #{self.current_filter}"
			self.refresh_menu
		end
		
		# initial update.
		self.current_filter = nil
		self.current_url = nil
		self.current_enquiry = nil
	end

	def setup_kvo_tracks
		observe_kvo NSApp.delegate.user, :tracks do |obj, change, ctx|
			puts "!! track change: #{change}"

			@input_field_menu.update_recent_items( change.kvo_new )
		end
	end

#=
	
	def handle_Activation_notification( notification )
		# pass the selection to the input field.
		if notification && notification.object
			self.update_with_selection notification.object[:selected_string]
		end
	end

	def update_with_selection( selection )
		if selection && ! selection.empty?

			self.input_field.stringValue = selection

			# simulate the field being edited.
			self.controlTextDidChange('stub notification')

			if self.submit_on_activation
				self.handle_field_submit(self)
			end
		end
	end

	def handle_Site_search_notification(notification)
		details = notification.object
		query_str = details[:query]
		self.current_enquiry = query_str

		self.display_mode = :Display_enquiry
	end

	def handle_Visit_request_notification( notification )
		self.display_mode = :Display_url
	end

#=

	def hide
		self.frame_view.visible = false
	end

	def show
		self.frame_view.visible = true
	end

	def visible
		self.frame_view.visible
	end
#=

	# for focus operations invoked from view layer.
	def handle_focus_input_field(sender)
		send_notification :Input_field_focused_notification

		unless @input_field.first_responder?
			@input_field.make_first_responder
		end
	end
	
	def focus_input_field
		@input_field.notification_on_next_first_responder = false
		@input_field.make_first_responder
	end

	def refresh_input_field
		# update the display string based on the display mode.
		self.display_string = 
			case self.display_mode.intern
			when :Display_enquiry
				self.current_enquiry
			when :Display_url
				self.current_url
			when :Display_filter
				self.current_filter
			else 
				raise "unknown display mode."
			end
			
			# self.input_text = nil
	end

	def handle_field_edit(sender)
		qb_debug "sender: #{sender}, input: #{@input_field.stringValue}"

		input_string = @input_field.stringValue

		# no-op if filter same as before.
		if input_string == self.current_filter
			qb_log "filter string same as before - doing nothing."
			return
		end
		
		self.current_filter = input_string
		
		# queue notification
		delayed_cancelling_previous filter_delay, -> {
			case input_string
			# we want to exceptionally map an empty input as an unfilter action.
			when nil || ''
				NSApp.delegate.user.perform_unfilter
			else
				NSApp.delegate.user.perform_filter(input_string)
			end
		}
	end
	
	def handle_field_submit(sender)
		new_input_string = @input_field.stringValue

		case new_input_string.qb_type
		when :enquiry
			self.current_enquiry = new_input_string
			self.current_url = self.current_enquiry.to_search_url_string
			
			self.input_text = new_input_string
			self.search_site
		else
			# it's a url.

			self.current_url = new_input_string
			self.current_enquiry = nil      
			
			# alternative approaches:
			# use previous enquiry
			# extract enquiry from url
			
			NSApp.delegate.user.perform_url_input(new_input_string)
		end
		
		self.refresh_input_field
	end

#=

	# TODO handle field submitted with mod key.
	def search_site
		qb_log "search site invoked."
		
		begin
			NSApp.delegate.user.perform_site_search(self.input_text)
		rescue Exception => e
			qb_report e
		end
	end
	
#= menu handling

	def setup_kvo_display_mode
		# update input field based on current display mode.
		observe_kvo self, :display_mode do |obj, change, context|
			self.refresh_input_field
		
			@input_field_menu.update_display_mode self.display_mode
			
			self.refresh_menu
		end
	end

	def refresh_menu
		@input_field.cell.setSearchMenuTemplate(@input_field_menu)
	end
	
	def handle_recent_item(sender)
		filter_text = sender.representedObject.filter_string
		
		@input_field.stringValue = filter_text
		
		self.controlTextDidChange('stub notification')
	end
	
	def handle_history_menu_item(sender)
		filter_text = ''
		
		@input_field.stringValue = filter_text
		
		NSApp.delegate.user.perform_unfilter
	end
	
#=

	def handle_display_mode_change( sender )
		self.display_mode = Display_tags_by_modes.key(sender.tag)
		
		# assuming the text field updated.
		# FIXME refactor to go through a User#perform_* method.
		unless self.display_mode == :Display_url
			self.handle_field_edit(self)
		end
	end
	
#=
	
	def mode
		if current_filter && ! current_filter.empty?
			:Filter
		else
			:Navigation
		end
	end

	# trigger kvc for display_mode when model attributes change.
	def self.keyPathsForValuesAffectingValueForKey(key)
		if key.eql? :display_mode
			return NSSet.setWithArray( [ :current_enquiry, :current_url, :current_filter ] + super.allObjects )
		else
			super
		end
	end
	
#= find handling - unused code (for now)
	
	def handle_find_initiation( sender )
		# coming from browser: take input if any selection, else use search / find input to prep find operation.
		
		# coming from input view: use search / find input.
		
		# coming from context gallery: not yet defined.
		
		self.initiate_find
	end
	
	# prep the input field for a find workflow.
	def initiate_find(find_text = nil)
		self.focus_input_field
		 
		@mode = :find
		
		# TODO change the visuals
		 
		find_text ||= nil # TODO use previous input
		self.display_string = find_text if find_text
	end
	
	def complete_find
		@mode = :default
	end
	
	def performFindPanelAction( sender )
		qb_log "find invoked."
		
		send_notification :Find_request_notification, @input_field.stringValue
		
		# take back focus.
		self.make_first_responder
	end
	
	
#= NSTextField integration points

	def control(control, textView:textView, doCommandBySelector:commandSelector)
		# returning true indicates no further handling of the input.
		
		case commandSelector.to_s
		when 'insertNewline:'
			return self.on_new_line
		when 'insertNewlineIgnoringFieldEditor:'
			return self.on_new_line_opt
		when 'cancelOperation:'
			return self.on_cancel_operation
		else 
			qb_log "command selector: #{commandSelector.to_s}"
			
			false
		end
	end

	def on_new_line
		#send_notification :Input_field_action_notification, nil
#				return true
		qb_log "handle newline."
		
		self.handle_field_submit(self)
		# self.refresh_input_field

		return true
	end

	def on_new_line_opt
		self.handle_field_edit(self)
		NSApp.delegate.user.perform_search(self.input_text, NSApp.delegate.user.default_site)
		
		return true
	end
	
	def on_cancel_operation    
		# TODO trigger reversion
		
		if @input_field.stringValue.empty?
			# cancel from empty field - should exit gallery mode.
			#qb_debug "restore saved field value"
			#self.restore_state
			self.refresh_input_field
			delayed_cancelling_previous 0, -> {
				send_notification :Input_field_cancelled_notification, nil
			}
			
			return true
		else	
			return false
		end
	end
	
	def controlTextDidBeginEditing( notification )

	end
		
	def controlTextDidChange( notification )
		qb_debug "textDidChange: #{notification.description}"
		
		self.input_text = @input_field.stringValue
		
		self.handle_field_edit(self)
	end
	
	def controlTextDidEndEditing( notification )
		qb_debug "endEditing"
		
		#		self.handle_field_submit @input_field
	end

#= menu validation
	# def validateMenuItem( menuItem )
	#   new_title = 
	#     case Display_tags_by_modes.key(menuItem.tag)
	#     when :Display_url then "Address: #{self.current_url}"
	#     when :Display_enquiry then "Enquiry: #{self.current_enquiry}"
	#     when :Display_filter then "Filter: #{self.current_filter}"
	#     else
	#       qb_warn "unknown menu tag #{menuItem.tag} from #{menuItem}"
	#       ''
	#     end
	#   
	#   menuItem.title = new_title
	#   
	#   true
	# end
end


class InputFieldMenu < NSMenu
	attr_accessor :url_menu_item
	attr_accessor :search_menu_item
	attr_accessor :filter_menu_item
	
	def update_display_mode( new_display_mode )
		case new_display_mode
		when :Display_url
			@url_menu_item.state = NSOnState
			@search_menu_item.state = NSOffState
			@filter_menu_item.state = NSOffState
		when :Display_enquiry
			@search_menu_item.state = NSOnState
			@url_menu_item.state = NSOffState
			@filter_menu_item.state = NSOffState
		when :Display_filter
			@search_menu_item.state = NSOffState
			@url_menu_item.state = NSOffState
			@filter_menu_item.state = NSOnState
		else
			raise "unknown display mode #{new_display_mode}"
		end
	end

	def update_recent_items( tracks )

		recent_items_size = 10
		@menu_item_start_position ||= self.itemArray.collect{|i| i.tag }.index(1000)

		# cut off the tracks to the recent items list size.
		index = [tracks.length, recent_items_size].min * -1
		reduced_tracks = tracks[index..-1].reverse

		reduced_tracks.each_with_index do |track, i|
			if ! @previous_tracks || (@previous_tracks[i] != track)
				position = @menu_item_start_position + i
				self.removeItemAtIndex(position) if position < self.numberOfItems
				item = self.insertItemWithTitle(track.descriptive_string, action:'handle_recent_item:', keyEquivalent:'', atIndex:position)
				item.representedObject = track
			end
		end

		@previous_tracks = reduced_tracks

	end

end

	
class InputField < NSSearchField
	include NSTextFieldResponderHandling
	
	attr_accessor :notification_on_next_first_responder

	def awakeFromNib
		
		super
		
		setup_responder_handlers
		
		self.track_mouse_up do |event, hit_view|
			qb_log "ding - mouse up"
		end
	end
	
	def setup_responder_handlers
		self.on_responder_handler = -> {
			if self.mouse_inside?
				self.selectText(self)
			end

			# work around the first responder bouncing between the input field and its field editor.
			if self.notification_on_next_first_responder
				send_notification :Input_field_focused_notification, nil
			end
			self.notification_on_next_first_responder = true
		}
		
		self.resign_responder_handler = -> {
			send_notification :Input_field_unfocused_notification
		}
	end
	
end


class NSString
	def to_search_url_string
		"http://google.com/search?q=#{CGI.escape(self)}"
	end
	
	def is_valid_url?
		return true if URI::DEFAULT_PARSER.regexp[:ABS_URI].match self
		return true if URI::DEFAULT_PARSER.regexp[:ABS_URI].match self.to_url_string
		false
	end
	
	def is_reachable_host?
		result = `ping -t 1 -c 1 #{self}`
		$?.exitstatus == 0
	end
	
	def is_single_word?
		self =~ /[ \.\/]/ ? false : true
	end

	def qb_type
=begin
		if ! self.is_valid_url? || 
			# exceptionally handle single words which aren't pingable as enquiries.
				(self.is_single_word? && ! self.is_reachable_host?)
=end
		if ! self.is_valid_url?
			:enquiry
		else
			:url
		end
	end
end


class ProgressIndicatorControl < NSControl
	
	def awakeFromNib
		super
		
		# set the cell
		self.cell = AMIndeterminateProgressIndicatorCell.alloc.init
		
		# set up cell properties
		self.cell.color = NSColor.grayColor
		self.cell.displayedWhenStopped = false
		
		# set up timer
	end
	
	def in_progress=( in_progress )
		# pass value to cell
		cell.spinning = in_progress
		
		# start/stop the timer
		if in_progress && ( ! @timer || ! @timer.isValid)
			@timer = NSTimer.scheduledTimerWithTimeInterval(self.cell.animationDelay, target:self, selector:'animate:', userInfo:nil, repeats:true)
			NSRunLoop.currentRunLoop.addTimer(@timer, forMode:NSDefaultRunLoopMode)
		else
			@timer.invalidate if @timer
		end
		
	end
	
	def animate( timer )
		# {	double value = fmod(([[testControl cell] doubleValue] + (5.0/60.0)), 1.0);
		self.cell.doubleValue = (self.cell.doubleValue + (5.0/60.0)).modulo(1.0)
		self.needsDisplay = true
	end
	
end
#
#  InputFieldViewController.rb
#  WebBuddy
#
#  Created by Park Andy on 13/10/2011.
#  Copyright 2011 __MyCompanyName__. All rights reserved.
#

# require 'cgi'
# require 'uri'

# require 'CocoaHelper'
# require 'appkit_additions'
# require 'KVOMixin'
# require 'defaults'


Display_tags_by_modes = { 
	Display_enquiry: 7001, 
	Display_url: 7002, 
	Display_filter: 7003 
}


# REFACTOR reorganise members.
# RENAME morphing into a toolbar controller.
class InputFieldViewController < PEViewController
	include KVOMixin
	include Reactive
	include DefaultsAccess
	
	attr_accessor :input_field

	Display_modes = [ :Display_enquiry, :Display_url, :Display_filter ]
	attr_accessor :display_mode # what's the input field supposed to display?


	attr_accessor :input_field_hit_box  # redundant view to catch clicks
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
	
	# ref to domain layer
	attr_accessor :user
	
	default :filter_delay
	default :selection_handling_behaviour
	default :submit_on_activation  # RENAME submit_on_update


	def defaults_root_key
		'ViewerWindowController.input_field_vc'
	end


	## debug the mysterious change for respondsToSelector.

	def respondsToSelector( selector )
		val_from_super = super

		val_from_respond_to = self.respond_to? selector

		if val_from_super == val_from_respond_to
			pe_debug "respondsToSelector: values from the sources are same."
			return val_from_super
		else
			pe_warn "respondsToSelector: deviating values for #{selector}! returning macruby version."
			return val_from_respond_to
		end
	end

	def setup
		super

		self.display_mode = :Display_enquiry
		
		if self.view
			self.setup_click_tracking
			self.setup_token_field
			
			self.setup_data_processing

			self.setup_kvo_display_mode
			self.setup_kvo_display_strings
			self.setup_kvo_tracks

			observe_notification :Activation_notification
			observe_notification :Site_search_notification
			observe_notification :Visit_request_notification

			self.refresh_input_field
		end
		
	end
	
	def setup_data_processing
		# TEMP debugging echo chamber
	  # react_to :current_enquiry do
	  # 	# OBSOLETE
   #    # self.search_site

   #    # TODO set when the url really loads.
   #    self.current_url = self.current_enquiry.to_search_url_string
   #  end

   #  react_to :current_url do
   #    self.current_enquiry = self.current_url
      
   #    # alternative approaches:
   #    # use previous enquiry
   #    # extract enquiry from url
      
   #    NSApp.delegate.user.perform_url_input self.input_text
   #  end
	end
	
#=

	def update_with_text( text )
		text = text.to_s

		self.input_field.stringValue = text

		# simulate the field being edited.
		self.controlTextDidChange('stub notification')

		if self.submit_on_activation
			self.handle_field_submit(self)
		end
	end
	
#=
	
	def handle_Activation_notification( notification )
		# pass the selection to the input field.
		if notification && notification.userInfo
			self.update_with_text notification.userInfo[:selected_string]
		end
	end

	def handle_Site_search_notification(notification)
		details = notification.userInfo
		
		query_str = details[:query]
		self.current_enquiry = query_str

		self.display_mode = :Display_enquiry
	end

	def handle_Visit_request_notification( notification )
		self.display_mode = :Display_url
	end

#= controller -> ui
	
	# this was slightly back-doorish in the days when we were trying to get page find input through this class. OBSOLETE
	def focus_input_field
		@input_field.notification_on_next_first_responder = false
		@input_field.make_first_responder
	end

	def refresh_input_field
		# update the display string based on the display mode.
		self.display_string = 
			case self.display_mode
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

#= ui -> controller

	#= mouse

	def setup_click_tracking
		# w = self.view.window
		# w.add_handler @input_field_hit_box, proc { |view|
		#   self.handle_focus_input_field(self)
		# }
	
		# watch the clicks and fire a notification.
		# why did we have to do this rather than watch first responder notifications? field editor concerns?
		@input_field.track_mouse_down do |event, view|
			pe_debug "clicked: #{event}"
			if view
				send_notification :Input_field_focused_notification
			end
		end

	end
	

	#= text input

	def handle_field_submit(sender)
		new_input_string = self.input_text

		NSApp.delegate.process_input new_input_string
		
		self.refresh_input_field
	end


	def handle_field_edit(sender)
		pe_trace "sender: #{sender}, input: #{@input_field.stringValue}"

		input_string = @input_field.stringValue

		# no-op if filter same as before.
		if input_string == self.current_filter
			pe_log "filter string same as before - doing nothing."
			return
		end
		
		self.current_filter = input_string
		
		# queue notification
		# SCAR this resulted some bizzare detatchment between input field and delegate
			# case input_string
			# when nil || ''
				# # exceptionally map an empty input as an unfilter action.
				# 	NSApp.delegate.user.perform_unfilter
			# else
				pe_trace "perform filter #{input_string}"
				NSApp.delegate.user.perform_filter(input_string)
			# end
	end
	
#= managing the menu

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

	def setup_kvo_display_mode
		# update input field based on current display mode.
		observe_kvo self, :display_mode do |obj, change, context|
			self.refresh_input_field
		
			@input_field_menu.update_display_mode self.display_mode
			
			self.refresh_menu
		end
	end

	def handle_display_mode_change( sender )
		self.display_mode = Display_tags_by_modes.key(sender.tag)
		
		# assuming the text field updated.
		# FIXME refactor to go through a User#perform_* method.
		unless self.display_mode == :Display_url
			self.handle_field_edit(self)
		end
	end
	

	def refresh_menu
		# disabled due to dep to NSSearchField
		# @input_field.cell.setSearchMenuTemplate(@input_field_menu)
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


	#= menu validation sysint

	def validateMenuItem( menuItem )

		# reflect current state on menu title.
		new_title = 
			case Display_tags_by_modes.key(menuItem.tag)
			when :Display_url then "Address: #{self.current_url}"
			when :Display_enquiry then "Enquiry: #{self.current_enquiry}"
			when :Display_filter then "Filter: #{self.current_filter}"
			else
			  pe_warn "unknown menu tag #{menuItem.tag} from #{menuItem}"
			  ''
			end  
		menuItem.title = new_title
		  
		true
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
		pe_log "find invoked."
		
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
		when 'insertTab:'
			return self.on_tab
		else 
			pe_debug "command selector: #{commandSelector.to_s}"
			
			false
		end
	end

	def on_new_line
		# NSTokenField
		# pe_log "forcing tokenisation"
		# @input_field.stringValue += ""

		#send_notification :Input_field_action_notification, nil
		pe_debug "handle newline."
		
		self.handle_field_submit(self)
		# self.refresh_input_field

		return true
	end

	def on_new_line_opt
		self.handle_field_edit(self)
		NSApp.delegate.user.perform_site_search self.input_text
		
		return true
	end
	
	def on_cancel_operation    
		# TODO trigger reversion
		
		if @input_field.stringValue.empty?
			# cancel from empty field - should exit gallery mode.
			#pe_debug "restore saved field value"
			#self.restore_state
			self.refresh_input_field
			delayed_cancelling_previous 0, -> {
				send_notification :Input_field_cancelled_notification
			}
			
			return true
		else	
			return false
		end
	end
	
	def controlTextDidBeginEditing( notification )
		pe_debug "beginEditing"
	end
		
	def controlTextDidChange( notification )
		pe_log "textDidChange: #{notification.description}"
		
		self.input_text = @input_field.stringValue.gsub TOPIC_DELIM, SEGMENT_DELIM

		self.tokenise_input

		self.handle_field_edit(self)
	end
		
	def controlTextDidEndEditing( notification )
		pe_debug "endEditing"
	end

#= token field integration

	TOPIC_DELIM = '&'
	SEGMENT_DELIM = ' '

	def setup_token_field
		@input_field.tokenizingCharacterSet = NSCharacterSet.characterSetWithCharactersInString('&')
		# @input_field.tokenizingCharacterSet = NSCharacterSet.characterSetWithCharactersInString(' ')	
	end
	
	def on_tab
	  # if in completion, complete and exit completion state. TODO
	end
	
	def tokenise_input
		# on new word, check if we should tokenise.
		if @input_field.currentEditor.textStorage.mutableString.end_with? ' '
			tokenised_text = self.tokenise self.input_text
			@input_field.stringValue = tokenised_text

			# append the space using the field editor.
			unless tokenised_text.end_with? '&'
				@input_field.currentEditor.textStorage.appendAttributedString NSAttributedString.alloc.initWithString ' '
			end
		end
	end
	
	def tokenise string
		segments = string.split(SEGMENT_DELIM)
		last_segment = segments.last
	  if tokens.include? last_segment
	  	return segments[0..-2].join(SEGMENT_DELIM) + "&" + last_segment + "&"
	  else
	  	string
	  end
	end

	def tokenField(field, styleForRepresentedObject:object)
		pe_log "token style callback for input: '#{object}'"

		if tokens.include? object
			NSDefaultTokenStyle  # this means it gets tokenised.
		else
			# object += ' ' unless object.end_with? ' '

			NSPlainTextTokenStyle  # this means it doesn't show as a token.
		end
	end

	# FIXME on enter, this makes a trailing space. remember last entered char and handle outside the field's string value.
	# def tokenField(field, displayStringForRepresentedObject:object)
	# 	# debug [object, field.tokens]

	# 	# # append space if object was the last token, in order to allow spacing in input.
	# 	# if field.tokens.last == object
	# 	# 	object + ' ' unless object.end_with? ' '
	# 	# else
	# 	# 	object
	# 	# end
	# end

	# def tokenField(field, representedObjectForEditingString:string)
	# 	pe_debug "token field called delegate method for editing string '#{string}'"

	# 	string + ' ' unless string[-1] == ' '

	# end

	def tokenField(field, shouldAddObjects:tokens, atIndex:index)
		pe_log "#{field} ## #{tokens} ## #{index}"

		tokens
	end

	def tokenField(field, completionsForSubstring:substring, indexOfToken:tokenIndex, indexOfSelectedItem:selectedIndex)
		pe_debug "on tokenfield delegate call for completion, string: #{field.stringValue}, substr: #{substring}, tokenIndex: #{tokenIndex}"

		selectedIndex[0] = -1

		segments = substring.split(' ')
		previous = segments[0..-2].join ' '
		last_segment = segments.last.to_s.downcase

		matching_tokens = self.tokens.select do |token|
			token.downcase.start_with? last_segment
		end

		unless previous.to_s.strip.empty?
			matching_tokens = matching_tokens.map do |token|
				# work around limitation on NSTokenField completion list behaviour by adding the previous text.
				previous + ' ' + token 
			end
		end

		matching_tokens
	end

	# SCAR experimenting with the NSTextField completion (cf NSTokenField token completion). should be triggered with NSTextView#complete
	# def control(control, textView:textView, completions:words, forPartialWordRange:charRange, indexOfSelectedItem:selectedIndex)
	# 	# pe_log "textView val: #{textView.stringValue}"

	# 	selectedIndex[0] = -1

	# 	last_segment = @input_field.stringValue.split(' ').last

	# 	vals = self.tokens.select do |token|
	# 		token.start_with? last_segment
	# 	end

	# 	pe_log "***** vals: #{vals}"

	# 	vals
	# end

	def tokenField(field, hasMenuForRepresentedObject:object)
		true
	end

	def tokenField(field, menuForRepresentedObject:object)
		stub_menu
	end

	def tokens
		# [ 'parenting', 'objc', 'coffee', 'coffee-2' ]  # STUB

		NSApp.delegate.user.context.tokens
	end

#= tracks

	def setup_kvo_tracks
		observe_kvo NSApp.delegate.user, :tracks do |obj, change, ctx|
			pe_log "!! track change. last track: #{NSApp.delegate.user.tracks.last}"

			@input_field_menu.update_recent_items( change.kvo_new )
		end
	end

end



class InputField < NSTokenField
	include NSTextFieldResponderHandling
	
	attr_accessor :notification_on_next_first_responder

	def awakeFromNib
		
		super
		
		setup_responder_handlers
		
		self.track_mouse_up do |event, hit_view|
			pe_log "ding - mouse up"
		end
	end
	
	def setup_responder_handlers
		self.on_responder_handler = -> {
			if self.mouse_inside?
				self.selectText(self)
			end

			# work around the first responder bouncing between the input field and its field editor.
			if self.notification_on_next_first_responder
				send_notification :Input_field_focused_notification
			end
			self.notification_on_next_first_responder = true
		}
		
		self.resign_responder_handler = -> {
			send_notification :Input_field_unfocused_notification
		}
	end

	#= field editor

	# override field editor's rangeForUserCompletion to make completion work nicely with plain text tokens.
	# def currentEditor
	# 	field_editor = super

	# 	# unless @field_editor_inited
	# 		class << field_editor
	# 			def rangeForUserCompletion
	# 				range = super

	# 				# # get range for last segment.
	# 				# str = self.textStorage.string
	# 				# separator_index = str.rindex(' ')
	# 				# offset = 
	# 				# 	if separator_index
	# 				# 		separator_index + 1
	# 				# 	else
	# 				# 		0
	# 				# 	end

	# 				# length = str.length - offset
	# 				# range = NSMakeRange(offset, length)

	# 				pe_log "***** rangeForUserCompletion: #{range.inspect}"
	# 				range
	# 			end
	# 		end

	# 		# @field_editor_inited = true
	# 	end

	# 	field_editor
	# end

	#= field editor delegate methods

	def textViewDidChangeSelection( notification )
		pe_debug "textDidChange: #{self.stringValue}"

		# DISABLED multiple token selection is unfinished.
		## trigger the menu for multiple token selection
		# if self.selected_tokens.to_a.size > 1
		# 	show_menu
		# end
	end

	#=

	def selected_tokens
		tokens = self.tokens
		range = self.currentEditor.selectedRange

		pe_log "tokens: #{tokens}, range: #{range.description}"

		if tokens.empty?
			[]
		else
			tokens.for_range range
		end

		# []
	end

	def tokens
		self.objectValue
	end

	def menu
		stub_menu
	end

	#= MOVE

	def show_menu
		# NSMenu.popUpContextMenu self.menu, withEvent:NSApp.currentEvent, forView:self
		# popup display location determined by the event's coordinates. how to align?
		# FIXME NSMenu becomes first responder so must use NSTableView.
		pe_log "TODO show input field menu."
	end
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


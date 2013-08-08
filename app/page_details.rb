class PageDetailsViewController < PEPopoverController
	extend IB
	
	include KVOMixin

  outlet :actions_bar_vc
  outlet :page_collection_vc
  outlet :page_collection_frame_view
  outlet :popover

	attr_accessor :should_dismiss
	attr_accessor :display_mode

	attr_accessor :input_action_button

	attr_accessor :actions_barvc	
	attr_accessor :actions_bar_frame_view

	#bindables
	attr_accessor :text_input
	attr_accessor :input_action_button_label


	# defaults
	attr_accessor :filter_delay

	def awakeFromNib
		super

		self.display_mode = :query

		self.filter_delay = 0.5
	end

	def setup
		super
		
		self.actions_barvc.frame_view = self.actions_bar_frame_view

		setup_kvo_text_input

		setup_reactive_filtering
	end
	
	def setup_kvo_text_input
		observe_kvo self, :text_input do |k,c,ctx|
			if self.popover.isShown
				pe_log "TODO show the button"
			end
		end
	end

	def setup_reactive_filtering
		@reaction_filtering = react_to 'text_input' do
			debug
			delayed_cancelling_previous filter_delay, -> {
				case self.text_input
				# we want to exceptionally map an empty input as an unfilter action.
				when nil || ''
					NSApp.delegate.user.perform_unfilter
				else
					NSApp.delegate.user.perform_filter(self.text_input)
				end
			}
		end
		# TODO additionally react to context change.

	end

	def refresh_button
		@input_action_button.keyEquivalent = "\r"

		self.input_action_button_label = "Go"
	end

	def show_popover(anchor_view = self.anchor_view)

		super

		refresh_button
	end

	def handle_input_action_button(sender)
		return unless self.text_input

		case self.text_input.pe_type
		when :enquiry

			NSApp.delegate.user.perform_search self.text_input
		else
			# it's a url.

			NSApp.delegate.user.perform_url_input self.text_input
		end
		

		# TODO dismissal
		self.should_dismiss = true
	end

	def hide_popover
	# 	if self.should_dismiss
			super
	# 		self.should_dismiss = false
	# 	else
	# 		pe_log "popover dismissal not allowed for #{self}"
	# 	end
	end
end


class PEViewController
	extend IB

	outlet :frame_view
end
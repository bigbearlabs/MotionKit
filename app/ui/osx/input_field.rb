Display_tags_by_modes = { 
  Display_enquiry: 7001, 
  Display_url: 7002, 
  Display_filter: 7003 
}

class InputFieldComponent < BBLComponent
  
  def setup_input_field
    @input_field_vc.setup

    react_to 'browser_vc.url' do |url|
      @input_field_vc.current_url = url
    end

    react_to 'stack.name' do |name|
      @input_field_vc.current_enquiry = name
    end

    react_to :input_field_shown do |shown|
      # view model -> view
      if shown
        if default :handle_focus_input_field
          @input_field_vc.show
        end

        # bar must be visible
        self.bar_shown = true
      else
        @input_field_vc.hide
      end
    end

    self.input_field_shown = default :handle_focus_input_field


    watch_notification :Input_field_focused_notification, @input_field_vc
    watch_notification :Input_field_unfocused_notification, @input_field_vc
    watch_notification :Input_field_cancelled_notification, @input_field_vc
  end

  def handle_hide_input_field(sender)
    self.input_field_shown = false
  end
  
  def handle_focus_input_field(sender)
    send_notification :Input_field_focused_notification

    self.input_field_shown = true

    @input_field_vc.focus_input_field
  end


  def handle_Input_field_focused_notification( notification )
    # self.show_popover(@nav_buttons_view)
  
    self.bar_shown = true

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
  
end



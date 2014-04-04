Display_tags_by_modes = { 
  Display_enquiry: 7001, 
  Display_url: 7002, 
  Display_filter: 7003 
}

class InputFieldComponent < BBLComponent
  include Reactive

  def on_setup

    @input_field_vc.setup

    react_to 'client.browser_vc.url' do |url|
      @input_field_vc.current_url = url
    end

    react_to 'client.stack.name' do |name|
      @input_field_vc.current_enquiry = name
    end

    react_to 'client.input_field_shown' do |shown|
      # view model -> view

      if shown
        ## BEGIN native input field
        if client.default :handle_focus_input_field
          @input_field_vc.show

          @input_field_vc.focus_input_field
        end

        # bar must be visible
        client.bar_shown = true

        ## END native input field

        # # ALT input field from plugin_vc
        # client.component(FilteringPlugin).focus_input_field
        
      else
        @input_field_vc.hide
      end

    end

    client.input_field_shown = client.default :handle_focus_input_field

    # client.extend ClientMethods
  end

end


# WORKAROUND add traits to client.
class BrowserWindowController < NSWindowController

  def focus_input_field
    pe_trace "may be redundant"
    self.handle_focus_input_field self
  end
  
  def handle_hide_input_field(sender)
    self.input_field_shown = false
  end
  
  def handle_focus_input_field(sender)
    pe_trace

    self.input_field_shown = true
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

end
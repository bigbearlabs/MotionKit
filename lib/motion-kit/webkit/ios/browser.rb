# a clunky name to denote a view that composes a BrowserVC and an input field.
class BrowserViewController < MotionViewController
  extend IB

  outlet :browser_vc

  def load_resource path
    load_file "#{NSBundle.mainBundle.resourcePath}/#{path}"
  end

  def load_file filename
    @browser_vc.load_file filename
  end
  
  def load_url url
    @browser_vc.load_url url
  end


  #= text field integration
  
  outlet :input_field

  def handle_input_changed(sender)
    input = sender.text

    case input
    when /^(js|javascript):/
      result = eval_js input
      puts result
      # NOTE result should strictly be a string.

      # self.js_alert result
    when /^http/
      @browser_vc.load_url input
    else
      begin
        # attempt to load file.
        @browser_vc.load_file input
      rescue
        # default to preprend http:// and re-call.
        sender.text = "http://#{sender.text}"
        self.handle_input_changed sender
      end
    end

  end
  
  def toggle_input sender
    input_field.hidden = ! input_field.hidden
    if input_field.hidden
      self.view.set_height self.view.height + input_field.height
    else
      self.view.set_height self.view.height - input_field.height
    end
  end

  #== ios platform integration layer

  #= input

  def textFieldShouldReturn(textField)
    # return pressed - just raise the event.
    self.handle_input_changed textField

    textField.resignFirstResponder
    
    true
  end
  
end
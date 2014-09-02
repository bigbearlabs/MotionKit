# a clunky name to denote a view that composes a BrowserVC and an input field.
class BrowserViewController < MotionViewController
  extend IB

  outlet :web_vc

  def viewDidLoad
    super

    web_vc.data_handler = self
  end

  def on_msg msg, callback
    puts "!!! on_msg: #{msg}, #{callback}"
  end
  
  #= loading

  def load_resource path
    case path
    when /^http/
      load_url path
    else
      begin
        load_file "#{NSBundle.mainBundle.resourcePath}/#{path}"
      rescue
        # default to preprend http:// and re-call.
        path = "http://#{path}"
        load_resource path
      end
    end

  end

  def load_file filename
    @web_vc.load_file filename
  end
  
  def load_url url
    @web_vc.load_url url
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
    else
      # attempt to load file.
      load_resource input
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
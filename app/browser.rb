class MotionViewController < UIViewController
  def load_view nib_name
      views = NSBundle.mainBundle.loadNibNamed nib_name, owner:self, options:nil
      self.view = views[0]
  end

end


class BrowserViewController < MotionViewController
  attr_accessor :web_view
  
  def awakeFromNib
    super
  end
  
  def handle_input_changed(sender)
    input = sender.text

    case input
    when /^js:/
      result = @web_view.stringByEvaluatingJavaScriptFromString input.gsub(/^js:/, '')
      puts result

      # @web_view.js_alert result
    else
      # default to treat it as a url.
      @web_view.load_url input
    end
    
  end
  
end


class UIWebView
  def load_url( url )
    url_obj = NSURL.URLWithString url
    req = NSURLRequest.requestWithURL url_obj
    self.loadRequest req
  end
  
  def js_alert( js )
    self.stringByEvaluatingJavaScriptFromString "alert(#{js})"
  end
end

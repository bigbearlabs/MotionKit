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
    
    @web_view.js_alert 'document'
  end
  
  def handle_input_changed(sender)
    # @web_view.load_url sender.text
    
    result = @web_view.stringByEvaluatingJavaScriptFromString sender.text
    puts result
    # @web_view.js_alert result
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

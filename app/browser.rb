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
      # NOTE result should strictly be a string.

      # @web_view.js_alert result
    else
      # default to treat it as a url.
      @web_view.load_url input
    end
    
  end
  
end


class UIWebView
  def load_bundle_file(name, extension = 'html')
    url = NSBundle.mainBundle.URLForResource(name, withExtension:extension, subdirectory:nil)
    self.load_url url
  end

  def load_url( url )
    case url
    when NSURL
      url_obj =  url
    else
      url_obj = NSURL.URLWithString url
    end

    req = NSURLRequest.requestWithURL url_obj
    self.loadRequest req
  end
  
  def js_alert( js )
    self.stringByEvaluatingJavaScriptFromString "alert(#{js});"
  end
end

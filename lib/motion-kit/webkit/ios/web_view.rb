motion_require '../../ui/view_controller'

# TODO this is the conceptual equivalent of the BrowserWindowController. Need to reconcile the compositional manager role between ios an osx.

class WebViewController < MotionViewController
  extend IB

  outlet :web_view
  
  attr_accessor :data_handler
  
  def viewDidLoad
    super

    setup_bridge

    puts "delegate: #{web_view.delegate}"
  end


#= objc-webview bridge

  def setup_bridge
    # DISABLED WVJSBridge
    @bridge ||= WebViewJavascriptBridge.bridgeForWebView(@web_view, handler: -> msg, callback {
      puts "got #{msg}"

      @data_handler.on_msg msg, callback
    })
  end


  #= objc -> webview
  
  def eval input
    eval_js input
  end
  
  def eval_js input
    tidied_input = input.gsub(/^(js|javascript):/, '')
    tidied_input = CGI::unescape tidied_input

    pe_log "evaluating js: #{tidied_input}"

    result = @web_view.stringByEvaluatingJavaScriptFromString tidied_input

  end
  


#= loading

  # TODO need to figure out how to get the files copied to the bundle.
  def load_file(name, location = :bundle)
    case location
    when :bundle
      url = name.to_url_string

      # check, fail to documents.
      exists = true  # stub
      unless exists
        self.load_file name, :documents
        return
      end
    when :documents
      # TODO
    end

    self.load_url url
  end

  def load_url( url )
    case url
    when NSURL
      url_obj =  url
    else
      url_obj = NSURL.URLWithString url
    end

    puts "loading url #{url_obj.absoluteString}"

    req = NSURLRequest.requestWithURL(url_obj)

    # ensure nib loading finished by poking the view.
    puts "view: #{self.view}"

    @web_view.loadRequest(req)

    # # work around fragment / query order incompatibility with angular.
    # @web_view.stringByEvaluatingJavaScriptFromString(
    #   %(
    #     window.location.href = #{url_obj.absoluteString};
    #   )
    # )
  end
  
end



class BBLWebView < PlatformWebView

  def js_alert( js )
    self.stringByEvaluatingJavaScriptFromString "alert(#{js});"
  end

end



class NSURLRequest
  def url
    self.URL
  end
end


class NSString
  def decode_uri_component
    self.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
  end
end

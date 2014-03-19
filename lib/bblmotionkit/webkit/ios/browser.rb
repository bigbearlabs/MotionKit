motion_require '../../ui/view_controller'

require "cgi"

# TODO this is the conceptual equivalent of the BrowserWindowController. Need to reconcile the compositional manager role between ios an osx.

class BrowserViewController < MotionViewController
  extend IB

  outlet :web_view
  
  attr_accessor :data_handler
  
  def awakeFromNib
    super
  end


  # parse the query string and perform the op. TODO
  def perform_op( query_hash )

    # dispatch_action query_hash["op"], query_hash
    # IMPL
    
    case query_hash['op']
    when 'load_url'
      load_url_in_overlay query_hash['url']  # CLEANUP
    when 'send_data'
      @data_handler.data_received BubbleWrap::JSON.parse( query_hash['data'] )
    else
      puts "can't handle query #{query_hash}"
    end
  end

  
  def eval_js input
    tidied_input = input.gsub(/^(js|javascript):/, '')
    tidied_input = CGI::unescape tidied_input

    pe_log "evaluating js: #{tidied_input}"

    result = @web_view.stringByEvaluatingJavaScriptFromString tidied_input

  end
  


  #= webview integration

  def webView(webView, shouldStartLoadWithRequest:request, navigationType:navigationType)
    # working with perform_op
    if request.url.last_path_segment.eql? "perform"
      puts "got request #{request.url.absoluteString}"

      @req = request
      puts request.description

      query = request.url.query.decode_uri_component
      self.perform_op Hash[*query.split(/&|=/)]

      return false

      # TODO async return to calling script. document protocol.
    end

    true
  end

#= loading

  # TODO need to figure out how to get the files copied to the bundle.
  def load_file(name, location = :bundle)
    case location
    when :bundle
      url = name.resource_url

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

    puts "loading url #{url_obj.description}"

    req = NSURLRequest.requestWithURL url_obj

    # ensure nib loading finished by poking the view.
    puts "view: #{self.view}"

    @web_view.loadRequest req
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

class WebViewController < BBLComponent
  include IvarInjection

  def initialize(client, deps)
    super(client)

    inject_collaborators deps
  end

  def on_setup
    init_bridge @web_view
  end
  
#=

  def load_url( urls, options = {})
    pe_log "loading urls #{urls}, options #{options}"

    urls = [ urls ] unless urls.is_a? Array

    case urls.compact.size
    when 0
      raise "no urls available in #{urls}"
    else
      fail_handler = -> url {
        # first call the one that's passed in.
        options[:fail_handler].call url if options[:fail_handler]

        default_fail_handler(urls[1..-1].to_a).call url
      }
    end
    @web_view.delegate.fail_handler = fail_handler


    @h2 = default_success_handler
    success_handler = -> url {
      h1 = options[:success_handler]
      h1.call url if h1
      @h2.call url
    }
    @web_view.delegate.success_handler = success_handler

    attach_callback_handler = -> {
      # set window.objc_interface_obj to be invoked from web layer  
      # RENAME, PUSH-DOWN
      callback_handler = details[:interface_callback_handler]
      if callback_handler
        key = 'objc_interface_obj'
        @browser_vc.register_callback_handler key, callback_handler
      end
    }
    # TODO integrate

    
    ## prep and set webview mainFrameURL.

    url = urls[0]
    # ensure we only deal with a string.
    url = 
      if url.is_a? NSURL
        url.absoluteString
      else
        url.to_url_string
      end
    
    # simplified version:
    @web_view.stopLoading(self)
    @web_view.mainFrameURL = url
  end
  
  def default_fail_handler fallback_urls = []
    load_failure_url = 'http://load_failure'

    @default_fail_handler =
      if fallback_urls.empty?
        -> url {
            @web_view.stopLoading(self)
            @web_view.mainFrameURL = load_failure_url
        }
      else
        -> url {
          # as long as there are fallback url's, keep loading.
          on_main_async do
            self.load_url fallback_urls
          end
        }
      end
  end

  def default_success_handler
    -> url {
      pe_log "success loading #{url}"
    }
  end

#=

  def init_bridge( web_view = NSApp.delegate.wc.browser_vc.web_view )
    original_delegate = web_view.delegate
    @bridge = WebViewJavascriptBridge.bridgeForWebView(web_view, 
      webViewDelegate: original_delegate,
      handler: -> data,responseCallback {
        pe_log "Received message from javascript: #{data}"
        responseCallback.call("Right back atcha") if responseCallback
    })
    @bridge.web_view_delegate = original_delegate  # to ensure calls to delegate from other collaborators are handled sensibly.
  end

#=

  # UNUSED SCAR this results in occasional PM's.
  def chain(*procs)
    @procs_holder ||= []
    ps = procs.dup
    lambda { |*params|
      # hackily retain a reference until all procs are done.
      @procs_holder << ps
      ps.map do |p|
        p.call *params unless p.nil?
      end
      @procs_holder.delete @procs_holder.index ps
    }
  end
  
end


# extensions to WebViewJavascriptBridge
class WebViewJavascriptBridge
  extend Delegating
  def_delegator :web_view_delegate

  def web_view_delegate
    @web_view_delegate
  end

  def web_view_delegate=(new_obj)
    @web_view_delegate = new_obj
  end


  #= implement missing delegate methods 

  def webView(webView, didStartProvisionalLoadForFrame:frame)
    @web_view_delegate.webView(webView, didStartProvisionalLoadForFrame:frame)
  end
  
  def webView(webView, didFailProvisionalLoadWithError:err, forFrame:frame)
    @web_view_delegate.webView(webView, didFailProvisionalLoadWithError:err, forFrame:frame)
  end
  
end



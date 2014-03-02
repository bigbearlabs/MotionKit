class WebViewController < BBLComponent
  include IvarInjection

  def log_level
    :warn
  end
  
  def initialize(client, deps)
    super(client)

    inject_collaborators deps
  end

  def on_setup
    init_bridge @web_view

    # setup downloads
    @download_delegate = DownloadDelegate.new downloads_path: default(:downloads_path)
    @web_view.downloadDelegate = @download_delegate
  end
  
#=

  def dev_extras=(enable)
    @web_view.preferences.developerExtrasEnabled = enable
  end

  def load_url( urls, options = {})
    unless urls.is_a? String or urls.is_a? NSURL or urls.is_a? Array
      raise "urls #{urls} is a bad type"
    end
    
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
        String.new(url).to_url_string
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
  
  def webView( webView, didReceiveTitle:title, forFrame:frame )
    @web_view_delegate.webView(webView, didReceiveTitle:title, forFrame:frame)    
  end

  def webView(webView, decidePolicyForMIMEType:mimeType, request:request, frame:frame, decisionListener:listener)
    @web_view_delegate.webView(webView, decidePolicyForMIMEType:mimeType, request:request, frame:frame, decisionListener:listener)
  end


  def webView(webView, willPerformClientRedirectToURL:url, delay:seconds, fireDate:date, forFrame:frame)
    @web_view_delegate.webView(webView, willPerformClientRedirectToURL:url, delay:seconds, fireDate:date, forFrame:frame)
  end
  
  def webView(webView, didCancelClientRedirectForFrame:frame)
    @web_view_delegate.webView(webView, didCancelClientRedirectForFrame:frame)
  end
  
  def webView(webView, didReceiveServerRedirectForProvisionalLoadForFrame:frame)
    @web_view_delegate.webView(webView, didReceiveServerRedirectForProvisionalLoadForFrame:frame)
  end

  def webView(webView, createWebViewWithRequest:request)
    @web_view_delegate.webView(webView, createWebViewWithRequest:request)
  end

  def webViewShow(webView)
    @web_view_delegate.webViewShow(webView)
  end

  def webView(webView, decidePolicyForNewWindowAction:actionInformation, request:request, newFrameName:frameName, decisionListener:listener)
    @web_view_delegate.webView(webView, decidePolicyForNewWindowAction:actionInformation, request:request, newFrameName:frameName, decisionListener:listener)
  end

  def webView(webView, unableToImplementPolicyWithError:error, frame:frame)
    @web_view_delegate.webView(webView, unableToImplementPolicyWithError:error, frame:frame)
  end
  
end



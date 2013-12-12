class WebViewController < BBLComponent
  include IvarInjection

  def initialize(client, deps)
    super(client)

    inject_collaborators deps
  end
  def on_setup
  end
  
  def load_url( urls, options = {})
    pe_debug "loading urls #{urls}, options #{options}"

    urls = [ urls ] unless urls.is_a? Array

    success_handler = chain options[:success_handler], default_success_handler
    fail_handler = chain options[:fail_handler], default_fail_handler( urls[1..-1])

    ## prep and set webview mainFrameURL.

    url = urls[0]
    # ensure we only deal with a string.
    url = 
      if url.is_a? NSURL
        url.absoluteString
      else
        url.to_url_string
      end
    
    @web_view.delegate.fail_handler = fail_handler
    # @web_view.delegate.success_handler = options[:success_handler]  # TODO rewire success handler to webview_delegate.

    # simplified version:
    @web_view.mainFrameURL = url
  end
  
  def default_fail_handler fallback_urls
    -> url {
      if fallback_urls.empty?
        self.load_url 'http://load_failure'
      else
        self.load_url fallback_urls
      end
    }
  end

  def default_success_handler
    -> url {
      pe_log "success loading #{url}"
    }
  end
  
  def chain(*procs)
    -> *params {
      procs.map do |p|
        p.call *params unless p.nil?
      end
    }
  end
  
end
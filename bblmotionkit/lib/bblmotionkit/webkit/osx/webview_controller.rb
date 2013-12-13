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

    case urls.compact.size
    when 0
      raise "no urls available in #{urls}"
    when 1
      # no fallback - add update the failure handler
      fail_handler = options[:fail_handler] or default_fail_handler
    else
      fail_handler = -> url {
        # first call the one that's passed in.
        options[:fail_handler].call url if options[:fail_handler]
        default_fail_handler(urls[1..-1]).call url
      }
    end

    @h2 = default_success_handler
    success_handler = -> url {
      h1 = options[:success_handler]
      h1.call url if h1
      @h2.call url
    }

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
          self.load_url fallback_urls
        }
      end
  end

  def default_success_handler
    -> url {
      pe_log "success loading #{url}"
    }
  end
  
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
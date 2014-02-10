# deps: 
# pod RoutingHTTPServer

module DynamicServer

  def start( port )
    @server = RoutingHTTPServer.alloc.init
    @server.interface = 'loopback'
    @server.port = port


    err = Pointer.new '@'
    @server.start err
    if err[0]
      raise err[0]
    else
      pe_log "#{@server} started serving."
    end
  end

  def on_request( request, response )
    # for view to fetch data. TEMP
    response.setHeader 'Access-Control-Allow-Origin', value:'*'

    pe_log "http request received: #{request.method} #{request.url.inspect}"
  end

  # TODO redundant given routinghttpserver. register directly
  def add_handler( path, *methods, &handler)
    on_request =  proc {|request, response|
      begin
        self.on_request request, response
        handler.call request, response            
      rescue Exception => e
        response.respondWithString e.to_s
      end
    }
    
    methods.map do |method|
      case method
      when :GET
        @server.get path, withBlock: on_request
      when :PUT
        @server.put path, withBlock: on_request
      end

      # TODO post.
    end
  end
  
end


class ServerComponent < BBLComponent
  include DynamicServer

  def on_setup
    if_enabled :start_server
  end

  def start_server
    prep_doc_root

    self.start default(:port)

    if_enabled :serve_plugins
  end

  def prep_doc_root
    docroot = "#{NSApp.app_support_path}/docroot"
    Dir.mkdir_p docroot unless Dir.exist? docroot

    plugins_dir = "#{NSApp.bundle_resources_path}/plugins"
    dest = "#{docroot}/plugins"
    cp plugins_dir, dest unless Dir.exist? dest
  end
  
  def serve_plugins
    @server.documentRoot = "#{NSApp.app_support_path}/docroot"
  end
  
  def on_entity_request method, path, handler_obj
    entity = path.match(/\w+$/)[0]
    handler_method = "handle_#{method}_#{entity}"
  
    raise "no method #{handler_method} defined on #{handler_obj}" unless handler_obj.respond_to? handler_method

    handler_p = proc {|request, response| 
      begin
        response.setHeader 'Access-Control-Allow-Origin', value:'*'

        params = request.params
        args = [ *params.values, request, response ]
        retval = handler_obj.send handler_method, *args

        response.setHeader("Content-Type", value:"text/plain")
        response.respondWithString(retval)
      rescue Exception => e
        response.respondWithString(e.to_s)
      end
    }

    case method
    when :get
      @server.put(path, withBlock:handler_p)
    when :post
      @server.post(path, withBlock:handler_p)
    when :put
      @server.put(path, withBlock:handler_p)      
    else
      raise "method '#{method}' not implemented!"
    end

    pe_log "now handling #{method} #{path} with #{handler_method}"
  end

  #=

  def cp src, dest
    error = Pointer.new :object
    NSFileManager.defaultManager.copyItemAtPath(src, toPath:dest, error:error)
    raise error[0].description if error[0]
  end
end

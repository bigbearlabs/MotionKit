# deps: 
# pod RoutingHTTPServer

module DynamicServer
  def start( port = 59123 )
    @server = RoutingHTTPServer.alloc.init
    @server.interface = 'loopback'
    @server.port = port

    # PULL-OUT
    @server.get('/*', withBlock:proc {|request, response|
      self.on_request request, response
    })
    @server.put('/*', withBlock:proc {|request, response|
      self.on_request request, response
    })
    # END PULL-OUT


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

    if request.url.path == '/'
      # TODO return index
      return
    end
    
    handlers_for_method(request.url.path, request.method.intern).map do |handler|
      handler.call request, response
    end
  end

  def handlers_for_method( path, method)
    # look up a handler.
    handlers_for_path = @handlers_by_path[path]
    handlers_for_method = (handlers_for_path || {})[method]
    handlers_for_method.to_a
  end
      
  def add_handler( path, method, &handler)
    @handlers_by_path ||= {}

    @handlers_by_path[path] ||= {}
    handlers_for_path = @handlers_by_path[path]

    handlers_for_path[method.intern] ||= []
    handlers_for_method = handlers_for_path[method.intern]

    handlers_for_method << handler
  end
  
end


class ServerComponent < BBLComponent
  include DynamicServer

  def on_setup
    self.start 59123
  end

end

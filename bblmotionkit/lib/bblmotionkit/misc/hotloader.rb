# deps: 
# pod RoutingHTTPServer

module DynamicServer
  def start( port = 59123 )
    @server = RoutingHTTPServer.alloc.init
    @server.interface = 'loopback'
    @server.port = port

    # PULL-OUT
    @server.get('/*', withBlock:proc {|request, response|
      pe_log "GET requested."

      # for view to fetch data. TEMP
      response.setHeader 'Access-Control-Allow-Origin', value:'*'

      self.on_request request, response
    })
    @server.put('/*', withBlock:proc {|request, response|
      pe_log "PUT requested."

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

end

module Hotloader
  include DynamicServer
  
  def on_request request, response
    resource_name = request.url.path
    content = request.body

    # just eval.
    result = eval content

    pe_log "hotloaded #{resource_name}: #{result}"

    response.respondWithString('OK!')
  rescue Exception => e
    pe_warn "hotloading #{resource_name} threw: #{e}"
    response.respondWithString('Hotload failed')
  end
end


# handle HTTP PUT requests with file.
class HotloaderComponent < BBLComponent
  include Hotloader

  def on_setup
    self.start 59123
  end  
end


# deps: 
# pod RoutingHTTPServer

module DynamicServer
  def start( port = 59123 )
    @server = RoutingHTTPServer.alloc.init
    @server.port = port

    @server.put('/*', withBlock:proc {|request, response|
      pe_log "PUT requested."

      self.handle_request request, response
      })

    err = Pointer.new '@'
    @server.start err
    if err[0]
      raise err[0]
    else
      pe_log "server started: #{@server}"
    end
  end

end

module Hotloader
  include DynamicServer
  
  def handle_request request, response
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
    self.start
  end  
end
module DynamicServer
  def start( port = 59123, &request_handler )
    @server = HTTPServer.alloc.init

    @server.port = port
    BlockInvoker.block = request_handler
    @server.connectionClass = BlockInvoker

    err = Pointer.new '@'
    @server.start err
    if err[0]
      raise err[0]
    else
      pe_log "server started: #{@server}"
    end
  end
end

class BlockInvoker < HTTPConnection
  class << self
    attr_accessor :block
  end

  # on request, yield to the block.
  def httpResponseForMethod(method, URI:path)
    self.class.block.call method, path

    super
  end

  def supportsMethod(method, atPath:path)
    case method
    when 'PUT'
      true
    else
      super
    end    
  end
  
end


class DynamicServerComponent < BBLComponent
  include DynamicServer

  def on_setup
    self.start do |method, path|
      puts "#{method} #{path}"
    end
  end
  
end
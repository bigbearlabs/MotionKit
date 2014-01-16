class HotloaderComponent < BBLComponent
  
  def on_setup
    NSApp.delegate.component(ServerComponent).add_handler '/source', :PUT do |request, response|
      on_request request, response
    end
  end

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


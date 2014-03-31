class DownloadDelegate

  def initialize( details = nil )
    @downloads_path = details[:downloads_path]
  end

  def download(download, decideDestinationWithSuggestedFilename:filename)
    file_path = File.join File.expand_path( @downloads_path ), filename
  
    pe_log "download path for #{download.request.inspect}: #{file_path}"
    download.setDestination(file_path, allowOverwrite: 
      true)
  end
  
  def downloadDidBegin( download )
    pe_log "begin download #{download.request.inspect}"
  end
  
  def downloadDidFinish( download )
    pe_log "finish download #{download.request.inspect}"
  end
  
  def download(download, didFailWithError:error_pointer)
    pe_log "error downloading #{download.request.inspect}"
  end
end



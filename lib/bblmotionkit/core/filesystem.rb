module FilesystemAccess
  
  def save( filename, content, location_sym = :docs )
    loc = parse_location_sym location_sym

    File.open(File.join(loc, filename), 'w') do |f|
      f << content
    end

    pe_log "wrote #{filename} at #{loc}"
  end
  
  def load( filename, location_sym = :docs )
    loc = parse_location_sym location_sym
    File.read(File.join(loc, filename))
  end

  def parse_location_sym(location_sym)
    case location_sym
    when :docs
      BW::App.documents_path
    else
      raise "unhandled location_sym #{location_sym}"
    end
  end
end


class NSString
  def resource_url
    nsurl = NSURL.fileURLWithPath(File.join(NSBundle.mainBundle.resourcePath, self))
    nsurl.to_s
  end
end


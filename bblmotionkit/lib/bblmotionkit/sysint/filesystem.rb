module FilesystemAccess
  
  def save( filename, content, location_sym = :docs )
    loc = parse_location_sym location_sym
    file = File.join(loc, filename)
    dir = File.dirname file
    Dir.mkdir_p dir unless File.directory? dir

    File.open file, "w" do |f|
      bytes = f.write content

      pe_log "wrote #{file}, (#{bytes} bytes)"
    end
  end
  
  def load( filename, location_sym = :docs )
    loc = parse_location_sym location_sym
    File.read(File.join(loc, filename))
  end
end

#== NS*

module FilesystemAccess
  def parse_location_sym(location_sym)
    case location_sym
    when :docs
      BW::App.documents_path
    when :bundle_resources
      NSApp.bundle_resources_path
    when :app_support
      NSApp.app_support_path
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


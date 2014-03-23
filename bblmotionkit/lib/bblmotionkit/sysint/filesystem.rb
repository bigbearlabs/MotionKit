module FilesystemAccess
  
  def save( filename, content, location_sym = nil )
    file = path filename, location_sym

    dir = File.dirname file
    Dir.mkdir_p dir unless File.directory? dir

    File.open file, "w" do |f|
      bytes = f.write content

      pe_log "wrote #{file}, (#{bytes} bytes)"
    end
  end
  
  def load( filename, location_sym = nil )
    file = path filename, location_sym

    File.read(file)
  rescue => e
    pe_report e, [filename, location_sym]
    raise e
  end

  def delete( filename, location_sym = nil )
    file = path filename, location_sym
    File.delete file

    pe_log "deleted #{file}"
  end
  
  def glob( pattern, location_sym = :docs )
    loc = parse_location_sym location_sym
    Dir.glob File.join(loc, pattern)
  end
  
end

#== NS*

module FilesystemAccess
  def path(relative_path, location_sym)
    if location_sym
      loc = parse_location_sym location_sym
      file = File.join(loc, relative_path)
    else
      file = relative_path
    end
  end
  
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


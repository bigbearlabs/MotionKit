class AppSupportStager < BBLComponent
  def on_setup
    unless default :staged
      # stage necessary resources to app support.
      pe_log "staging resources."

      FileUtils.cp_r "#{NSApp.bundle_resources_path}/bookmarklets", "#{NSApp.app_support_path}/bookmarklets"

      update_default :staged, true
    end
  end

  def defaults_spec
    {}
  end
  
end



# duck punch
class FileUtils
  def self.rmdir dir
    if Dir.exist? dir
      error = Pointer.new :object
      NSFileManager.defaultManager.removeItemAtPath(dir, error:error)
      raise error[0].description if error[0]
    end
  end
  
  def self.cp_r src, dest
    error = Pointer.new :object
    NSFileManager.defaultManager.copyItemAtPath(src, toPath:dest, error:error)
    if error[0]
      if error[0].code == 516
        # file exists.
      else
        raise error[0].description 
      end
    end
  end
end

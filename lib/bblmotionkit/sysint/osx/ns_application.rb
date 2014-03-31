class NSApplication

  def activate
    activateIgnoringOtherApps(true)
  end

  def name
    NSRunningApplication.currentApplication.localizedName
  end
  
  def bundle_id
    NSBundle.mainBundle.bundleIdentifier
  end

  def pid
    NSRunningApplication.currentApplication.processIdentifier
  end
  
  def icon
    applicationIconImage
  end
  
  #= path access

  def app_support_path
    NSFileManager.defaultManager.privateDataPath
  end

  def bundle_resources_path
    NSBundle.mainBundle.resourcePath
  end
  
  #=

  def status_bar_window
    selection = self.windows.select do |w|
      w.is_a? NSStatusBarWindow
    end

    if selection.size != 1
      pe_warn "unexpected results for #status_bar_window: #{selection}"
    end

    selection.first
  end

  #=

  def windows_report
    ws = windows.collect do |w|
      w.to_s + ":" + w.title.to_s
    end
    ws.to_s + ", keyWindow: " + self.keyWindow.to_s + ", mainWindow: " + self.mainWindow.to_s
  end

end


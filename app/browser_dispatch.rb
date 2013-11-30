class BrowserDispatch < BBLComponent
  include GetUrlHandler

  Keycodes = {
    shift: NSShiftKeyMask,
    opt: NSAlternateKeyMask
  }

  def on_setup
    register_url_handling    
  end
  
  # the handler for url invocations from the outside world.
  def on_get_url( details )
    url_event = details[:url_event]
    url = details[:url]

    current_modifiers = NSEvent.modifiers

    # HACK!!! very brittle coupling to defaults structure
    handler_specs = default :click_handler_specs

    # dispatch to the right handler spec based on what keys are pressed.
    if ( (current_modifiers & Keycodes[:shift]) != 0 && ( current_modifiers & Keycodes[:opt]) != 0 )
      bundle_id = handler_specs[2][:browser_bundle_id]
    elsif (current_modifiers & Keycodes[:opt]) != 0
      bundle_id = handler_specs[1][:browser_bundle_id]
    else
      bundle_id = handler_specs[0][:browser_bundle_id]
    end

    load_url_proc = -> {
      pe_debug "open #{url} with #{bundle_id}"
      self.open_browser bundle_id, url
    }

    # if @main_window_controller
    load_url_proc.call
    # else
    #   @pending_handlers ||= []
    #   @pending_handlers << load_url_proc
    # end
  end

  # OBSOLETE salvage any difference and remove.
  def open_browser(browser_id, url_string)  
    pe_log "request to handle url in #{browser_id}"
    
    case browser_id
    # me!!!
    when /#{NSApp.bundle_id}/i
      client.load_ext_url_in_space_window url: url_string

      return
      
    # some special cases for space-aware url opening.
    when :Safari
      @browser_process = SafariProcess.new @spaces_manager
      @browser_process.open_space_aware url_string
    when :Chrome
      @browser_process = ChromeProcess.new @spaces_manager
      @browser_process.open_space_aware url_string
    else
      Browsers::open_url( url_string, browser_id )
    end
  end
  
end
class BrowserDispatch < BBLComponent
  include GetUrlHandler

  Keycodes = {
    shift: NSShiftKeyMask,
    opt: NSAlternateKeyMask
  }

  def on_setup
    register_url_handling    
  end
  
  #=

  def defaults
    {
      click_handler_spec: {
        postflight: -> new_specs {
          # TODO does there need to be anything?
        },
        preference_spec: {
          view_type: :list,
          label: 'Click on URL',
          list_items_accessor: :installed_browsers_menu,
          list_select_handler: -> menu_item {
            # TODO from menu item, generate new spec and write default.
          }
        }

        # MAYBE post_register to specify actions after defaults registered.
        # MAYBE initial val
      },
      # opt_click_handler_spec
      # opt_shift_click_handler_spec
    }
  end

  #=

  def installed_browsers_menu
    get_description = proc { |entry_key, details| 
      desc = details[:description].tap do |desc|
        # default to the entry key.
        desc = entry_key if desc.to_s.empty?
      end
    }

    menu_data = Browsers.installed_browsers.map do |entry_key, details|
      { 
        title: get_description.call(entry_key, details),
        icon: details[:icon],
        value: details[:bundle_id],
      }
    end
    pe_debug "created menu data #{menu_data}"

    new_menu menu_data
  end

  
  # the handler for url invocations from the outside world.
  def on_get_url( details )
    url_event = details[:url_event]
    url = details[:url]

    handler_specs = default :click_handler_specs

    # based on modifiers, dispatch to corresponding browser.
    # HACK!!! very brittle coupling to defaults structure. re-arranging list will break browser dispatch.
    current_modifiers = NSEvent.modifiers
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
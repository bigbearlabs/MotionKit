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

  def defaults_spec
    {
      click_handler: {
        postflight: -> new_specs {
          # TODO does there need to be anything?
        },
        preference_spec: {
          view_type: :list,
          label: 'Click on URL',
          list_items_accessor: :installed_browsers_menu,
        }
        # MAYBE initial val
      },
      opt_click_handler: {
        postflight: -> new_specs {
          # TODO does there need to be anything?
        },
        preference_spec: {
          view_type: :list,
          label: 'Alt/Option + Click on URL',
          list_items_accessor: :installed_browsers_menu,
        }
      },
      shift_opt_click_handler: {
        postflight: -> new_specs {
          # TODO does there need to be anything?
        },
        preference_spec: {
          view_type: :list,
          label: 'Shift + Alt/Option + Click on URL',
          list_items_accessor: :installed_browsers_menu,
        }
      },
    }
  end

  #=

  def installed_browsers_menu
    menu_data = Browsers.installed_browsers.map do |bundle_id, details|
      description = details[:description]
      description ||= bundle_id
      { 
        title: description,
        icon: details[:icon],
        value: bundle_id
      }
    end
    pe_debug "created menu data #{menu_data}"

    new_menu menu_data
  end

  
  # the handler for url invocations from the outside world.
  def on_get_url( details )
    url_event = details[:url_event]
    url = details[:url]

    # based on modifiers, dispatch to corresponding browser.
    # HACK!!! very brittle coupling to defaults structure. re-arranging list will break browser dispatch.
    current_modifiers = NSEvent.modifiers
    if ( (current_modifiers & Keycodes[:shift]) != 0 && ( current_modifiers & Keycodes[:opt]) != 0 )
      bundle_id = default :shift_opt_click_handler
    elsif (current_modifiers & Keycodes[:opt]) != 0
      bundle_id = default :opt_click_handler
    else
      bundle_id = default :click_handler
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
class WebBuddyAppDelegate
#= carouselling

  def setup_kvo_carousel_state
    # watch active status to set the carouselling.
    observe_kvo self, :active_status do |k,c,ctx|
      pe_log "active_status #{active_status}"
      case active_status
      when :activating, :activated
        # carouselling if mod key down.
        if ! activation_modifier_released?
          start_carouselling
        else
          # turn carouselling off.
          stop_carouselling
        end
      else
        stop_carouselling
      end
    end

    # watch carouselling status to load selected tool.
    # observe_kvo self, :carouselling do |k,c,ctx|
    #   if self.carouselling
    #     show_switcher
    #   else
    #     load_selected_tool
    #   end
    # end
  end

  attr_accessor :carouselling

  def start_carouselling
    self.carouselling = true

    self.show_switcher
  end

  def stop_carouselling
    self.carouselling = false

    load_selected_tool
  end

#= switcher integration point

  def hotkey_action_switcher( params )
    event = params[:event]
    pe_debug "handling hotkey event. #{event.description} active app: #{NSWorkspace.sharedWorkspace.activeApplication}"
    
    if ! carouselling
      # this is the initial invocation
      self.toggle_main_window({ activation_type: :hotkey })
      else
      # this is a subsequent invocation
      self.select_next_tool
    end
    
    if activation_modifier_released?
      stop_carouselling
    end
  end

  def show_switcher
    @main_window_controller.browser_vc.load_switcher

    if activation_modifier_released?
      stop_carouselling
    end
  end
  
  def select_next_tool
    pe_log "select next tool"
    
    # tactical impl
    @main_window_controller.browser_vc.select_next_tool
    # NOTE strategic would be:
    # @switcher.select_next_tool
  end

  def load_selected_tool
    pe_log "load selected tool"
    
    @main_window_controller.browser_vc.load_selected_tool
  end

end


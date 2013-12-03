class DefaultBrowserHandler < BBLComponent

  #= app lifecycle

  def on_setup
    
    if default :make_default_browser
      # TODO show user dialog if setting needs to change

      make_default_browser
    else
      save_previous_if_needed
    end
  end

  def on_terminate
    pe_log "#{self}#on_terminate"
  end

  #= framework integration
  
  def defaults_spec
    {
      make_default_browser: {
        postflight: -> val {
          puts "** val: #{val}"
          if val
            make_default_browser
          else
            revert_default_browser
          end
        },
        preference_spec: {
          view_type: :boolean,
          label: "Make #{NSApp.name} my default browser",
        }
        # MAYBE post_register to specify actions after defaults registered.
        # MAYBE initial val
      }
    }
  end
  # TODO find a Hash subclass with guaranteed order


  #= 

  def make_default_browser
    save_previous_if_needed

    Browsers::set_default_browser NSApp.bundle_id
  end

  def revert_default_browser
    previous_browser_bid = default :previous_default_browser
    unless previous_browser_bid.to_s.empty?
      Browsers::set_default_browser previous_browser_bid
    else
      pe_log "no previous browser bid found, can't revert default browser"
    end
  end

  #=

  def save_previous_if_needed
    previous_browser_bid = Browsers::default_browser

    if NSApp.bundle_id.casecmp(previous_browser_bid) == 0
      pe_log "previous browser: #{previous_browser_bid} not saving"

    else
      pe_log "saving previous browser: #{previous_browser_bid}"

      self.update_default :previous_default_browser, previous_browser_bid
    end
  end
  
end
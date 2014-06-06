class MotionKitAppDelegate < ProMotion::Delegate
end

class AppDelegate < MotionKitAppDelegate

  def on_load(application, options)
    
    browser_vc = BrowserViewController.new
    setup_window browser_vc

    
    browser_vc.load_resource 'http://coffeenotes.io'

    # browser_vc.toggle_input self  # TODO wire up with ui event.

    true
  end
  
end

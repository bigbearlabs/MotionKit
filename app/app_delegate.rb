class AppDelegate < MotionKitAppDelegate

  def on_load(application, options)
    
    browser_vc = BrowserViewController.new
    setup_window browser_vc
    
    resource_path = 'http://flappybird.io'
    
    browser_vc.load_resource resource_path
    
    # browser_vc.toggle_input self  # TODO wire up with ui event.

    true
  end
  
end

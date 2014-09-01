class MotionKitAppDelegate < ProMotion::Delegate
end

class AppDelegate < MotionKitAppDelegate

  def on_load(application, options)
    
    browser_vc = BrowserViewController.new
    setup_window browser_vc

    app.stage_resource 'docroot', app.app_support_path
    
    # browser_vc.load_url 'http://localhost:9000'
    browser_vc.load_resource 'docroot/index.html'

    # browser_vc.toggle_input self  # TODO wire up with ui event.

    true
  end
  
  def group_id
    # STUB
    "group.com.bigbearlabs.Clips"
  end
end

class AppDelegate < ProMotion::Delegate

  def on_load(application, launchOptions)
    
    browser_vc = BrowserViewController.new
    setup_window browser_vc
    
    browser_vc.toggle_input self  # TODO wire up with ui event.

    resource_path = 'http://flappybird.io'
    resource_path = 'plugins/index.html#/sneakers/quiz'

    browser_vc.load_resource resource_path
    
    true
  end
  

  #= 

  def setup_window root_view_controlelr
    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.makeKeyAndVisible
    @window.rootViewController = root_view_controlelr
    @window.rootViewController.wantsFullScreenLayout = true
  end

  #=
  
end

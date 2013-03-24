class AppDelegate
  def application(application, didFinishLaunchingWithOptions:launchOptions)
    
    setup_window 
    
    setup_root_vc
    
    # test out a repl.
    # r = repl self
    # puts "repl: #{r}"
    # puts r.evaluateExpression 'self'
    
    true
  end
  
  def setup_window
    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.makeKeyAndVisible
  end

  def setup_root_vc
    browser_vc = BrowserViewController.alloc.init
    browser_vc.load_view 'Browser'
    
    @window.rootViewController = browser_vc
    
    @window.rootViewController.wantsFullScreenLayout = true
    
    # @window.addSubview browser_vc.view
  end
  
  #=
  
  def root_vc
    @window.rootViewController
  end
end

# TODO refactor into MotionKitAppDelegate.

class AppDelegate
  def load_url url
    browser_vc.load_url url
  end

  def browser_vc
    @window.rootViewController
  end

  #= 

  def application(application, didFinishLaunchingWithOptions:launchOptions)
# motion_require '../ProMotion/lib/ProMotion.rb'

# class AppDelegate < ProMotion::Delegate
#   def on_load(application, launchOptions)
    
    browser_vc = BrowserViewController.new
    setup_window browser_vc
    
    browser_vc.toggle_input self  # TODO wire up with ui event.

    # browser_vc.load_file 'testfile.html'
    browser_vc.load_url 'http://flappybird.io'


    # test out a repl.
    # r = repl self
    # puts "repl: #{r}"
    # puts r.evaluateExpression 'self'
    
    true
  end
  

  def setup_window vc
    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.makeKeyAndVisible
    @window.rootViewController = vc
    @window.rootViewController.wantsFullScreenLayout = true
  end

  #=
  
end

class MotionKitAppDelegate < ProMotion::Delegate

  def setup_window root_view_controller
    @window = UIWindow.alloc.initWithFrame(UIScreen.mainScreen.bounds)
    @window.makeKeyAndVisible
    @window.rootViewController = root_view_controller
    @window.rootViewController.wantsFullScreenLayout = true
  end

  def hide_status_bar
    UIApplication.sharedApplication.setStatusBarHidden(true, withAnimation:UIStatusBarAnimationNone)
  end

end

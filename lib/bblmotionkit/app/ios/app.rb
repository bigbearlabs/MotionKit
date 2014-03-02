class BW::App
  def hide_status_bar
    UIApplication.sharedApplication.setStatusBarHidden(true, withAnimation:UIStatusBarAnimationNone)
  end
end
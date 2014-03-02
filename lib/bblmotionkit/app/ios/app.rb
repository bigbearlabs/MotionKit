module BW::App
  module_function
  
  def hide_status_bar
    UIApplication.sharedApplication.setStatusBarHidden(true, withAnimation:UIStatusBarAnimationNone)
  end
end
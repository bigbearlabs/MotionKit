PlatformViewController = 
	if BubbleWrap::App.ios?
		UIViewController
	else
		NSViewController
	end

class MotionViewController < PlatformViewController
=begin
  def load_view nib_name
      views = NSBundle.mainBundle.loadNibNamed nib_name, owner:self, options:nil
      self.view = views[0]
  end
=end

  def init( nib_name = self.class.name.gsub(/Controller$/,'') )
    obj = self.initWithNibName(nib_name, bundle:nil)
    obj
  end

end


PlatformView = 
  if BubbleWrap::App.ios?
    UIView
  else
    NSView
  end

class PlatformView
  def width
    self.frame.size.width
  end
  
  def height
    self.frame.size.height
  end

  def hidden
    self.isHidden
  end

  def visible
    ! self.isHidden
  end

  def x
    self.frame.origin.x
  end

  def y
    self.frame.origin.y
  end

  def move_x offset
    new_frame = NSMakeRect( frame.origin.x + offset, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end

  def set_x new_x
    new_frame = NSMakeRect( new_x, frame.origin.y, frame.size.width, frame.size.height)
    self.frame = new_frame
  end


#=

  def fit_superview
    self.frame = self.superview.bounds
  end

end


PlatformWebView = 
  if BubbleWrap::App.ios?
    UIWebView
  else 
    WebView
  end


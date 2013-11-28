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


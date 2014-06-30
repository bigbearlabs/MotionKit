class PlatformView
  
  def x
    self.frame.origin.x
  end

  def y
    self.frame.origin.y
  end

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


#=

  def frame_for_subviews
    union = nil
    self.subviews.each do |v|
      union ||= v.frame
      union = CGRectUnion(union, v.frame)
    end
    
    union || CGRectZero
  end

  def center
    CGPointMake(self.frame.origin.x + (self.width/2), self.frame.origin.y + (self.height/2))
  end
  

#= setters

  def x=( x )
    self.frame = CGRectMake(x, y, width, height)
  end
  
  def y=( y )
    self.frame = CGRectMake(x, y, width, height)
  end

  def width=( width )
    self.frame = CGRect.rect_with_center self.center, width, height
  end

  def height=( height, options = {} )
    case options[:anchor]
    when :top
      self.frame = CGRectMake(x, y, width, height)
      # FIXME generalise platform-specific coordinate details
    else
      self.frame = CGRect.rect_with_center self.center, width, height
    end
  end


  def visible=( is_visible )
    self.hidden = ! is_visible
  end
  

  def center=(new_center)
    new_x = new_center.x - (self.width / 2)
    new_y = new_center.y - (self.height / 2)
    self.frame = CGRectMake(new_x, new_y, self.width, self.height)
  end


#= mutating behaviour

  def fit_superview
    self.frame = self.superview.bounds
  end

end


class Math
  def self.to_radian(degrees)
    degrees * Math::PI / 180.0
  end
end


class CGRect
  def center
    CGPointMake( CGRectGetMidX(self), CGRectGetMidY(self) )
  end
end


class UIBezierPath
  def paint( stroke_color = NSColor.blueColor, fill_color = NSColor.redColor )

    stroke_color.setStroke
    self.stroke
    
    fill_color.setFill
    self.fill
  end
  
end
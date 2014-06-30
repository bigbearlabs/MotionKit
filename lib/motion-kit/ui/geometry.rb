class Math
  def self.to_radian(degrees)
    degrees * Math::PI / 180.0
  end
end


class CGRect
  def center
    CGPointMake( CGRectGetMidX(self), CGRectGetMidY(self) )
  end

  def self.rect_with_center(center, width, height)
    # center.x = origin.x + mid(width), center.y = origin.y + mid(height)
    x = center.x - (width / 2)
    y = center.y - (height / 2)
    
    CGRectMake(x, y, width, height)
  end

end


class UIBezierPath
  def paint( stroke_color = NSColor.blueColor, fill_color = NSColor.redColor )

    stroke_color.setStroke
    fill_color.setFill
    
    self.stroke
    self.fill
  end
  
end
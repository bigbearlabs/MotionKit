if BW::App.ios?

  class UIApplication
    def window
      self.windows[0]
    end

    def controller
      self.window.rootViewController
    end
  end

  def app
    UIApplication.sharedApplication
  end

  class UIView

  #= radian

    def radian_for_point( p, q = self.center )
      deltaVector = CGPointMake(p.x - q.x, p.y - q.y)
      angle = Math.atan(deltaVector.y / deltaVector.x) + (deltaVector.x < 0 ? Math::PI : 0)
    end
    
  #= convenience

    def fit_superview
      if self.superview
        self.frame = self.superview.bounds
      end
    end
    
    def rotate( angle_rad)
      transform = CGAffineTransformMakeRotation(angle_rad)
      self.transform = transform
    end

    # geometry changes - until we figure out the deal with flippedness, leave this here.

    def set_height height, anchor = :bottom
      case anchor
      when :bottom
        diff = self.height - height  # -ve if growing.
        new_y = self.y + diff 
        self.frame = CGRectMake( x, new_y, self.width, height )
      else
        raise "unknown anchor #{anchor}"
      end
    end


  end


  class CALayer

    # not working?
    def rotate( angles_rad )
      # self.transform = CATransform3DMakeRotation(angles_rad, 0, 0, 1)
      self.transform = CATransform3DRotate(self.transform, angles_rad, 0.0,0.0,0.0)
      self.setNeedsDisplay
    end

    def self.new_layer( frame )
      CALayer.layer.tap do |obj|
        obj.frame = frame
      end
    end
    
    def circle( radius, args = nil )
      args[:width] ||= 1
      args[:stroke] ||= :red
      args[:fill] ||= :clear

      CAShapeLayer.layer.tap do |layer|
        self.add_layer layer
    
        path = UIBezierPath.bezierPathWithArcCenter(self.center, radius:radius, startAngle:0, endAngle:2*Math::PI, clockwise:true)

        layer.path = path.CGPath

        layer.lineWidth = args[:width]
        layer.strokeColor = args[:stroke].to_color.CGColor
        layer.fillColor = args[:fill].to_color.CGColor
      end
    end
    
    def add_layer layer
      self.addSublayer layer
      layer.frame = self.bounds
      layer
    end

    def center
      CGPointMake( CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) )
    end  

  end


  class CIImage
    def blurred_image( filter_options = {} )
      blur_filter = CIFilter.filterWithName('CIGaussianBlur')
      raise Exception.new("Filter not found: #{filter_name}") unless blur_filter

      blur_filter.setDefaults
      blur_filter.setValue(self, forKey:'inputImage')
      filter_options.each_pair do |key, value|
        blur_filter.setValue(value, forKey:key)
      end
      output = blur_filter.valueForKey('outputImage')

      context = CIContext.contextWithOptions(nil)
      cg_output_image = context.createCGImage(output, fromRect:output.extent)
      output_image = CIImage.imageWithCGImage(cg_output_image)
    end
  end


  def new_blur_filter
    blur_filter = CIFilter.filterWithName('CIGaussianBlur')
    raise Exception.new("Filter not found: #{filter_name}") unless blur_filter

    blur_filter.setDefaults

    blur_filter
  end


  class UIImageView

    attr_accessor :image_name

    def setImage_name(image_name)
      @image_name = image_name
      self.image = UIImage.imageNamed(@image_name)
    end

  end
end
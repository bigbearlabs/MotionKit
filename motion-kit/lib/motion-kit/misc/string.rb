class NSAttributedString
  def attributes
    self.attributesAtIndex(0, effectiveRange:nil)
  end

  def range
    NSMakeRange(0, length)
  end
  
end

class NSMutableAttributedString
  def self.new( attr_str )
    self.alloc.initWithAttributedString attr_str
  end
  
  def color=(color)
    self.beginEditing

    self.addAttribute('NSColor', value:color, range:self.range)

    self.endEditing
  end
  
end
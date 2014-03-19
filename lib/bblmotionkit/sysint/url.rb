class NSURL
  def last_path_segment
    return '' if self.path.nil?
    
    segments = self.path.split('/')
    segments ? segments.last : ''

  end

  def inspect
    self.description
  end
  
end


class NSString
  include StringIdioms

  def to_url
    # NOTE we need to first check if string needs encoding. if string alrady percent-escape encoded, we shouldn't encode again.
    # self = self.escaped
    url = (
      if self.start_with? '~'
        NSURL.fileURLWithPath( self.stringByExpandingTildeInPath )
      elsif self.start_with? '/'
        NSURL.fileURLWithPath self
      else
        NSURL.URLWithString self
      end
    )

    pe_debug  "#{url.description}, #{url.class}"
    
    return url
  end  

  #= wrappers

  def to_base_url
    url = NSURL.URLWithString(self)
    "#{url.scheme}://#{url.host}"
  end

end


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
    
    if url.nil?
      # CASE from the wild: threadless
      # http%3a%2f%2fview.email.threadless.com%2f%3fj%3dfe6116707263017b7614%26m%3d%%ex2%3bMemberID%%%26ls%3d%%ex2%3blistsubid%%%26l%3d%%ex2%3blistid%%%26s%3d%%ex2%3bSubscriberID%%%26jb%3d%%ex2%3b_JobSubscriberBatchID%%%26ju%3d%%ex2%3bjoburlid%%&r=0
      url = self.gsub('%%', '').to_url
    end

    raise "can't create url with #{self}" unless url.is_a? NSURL
    return url
  end  

  #= wrappers

  def to_base_url
    url = NSURL.URLWithString(self)
    "#{url.scheme}://#{url.host}"
  end

end


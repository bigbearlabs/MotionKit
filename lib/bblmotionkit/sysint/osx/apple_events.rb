class NSAppleEventDescriptor
  def url_string
    # translated from GTM sample code 
    
    url_string = self.paramDescriptorForKeyword(KeyDirectObject).stringValue
    
    raise "error extracting url from #{self}" unless url_string
    
    url_string
  end
end


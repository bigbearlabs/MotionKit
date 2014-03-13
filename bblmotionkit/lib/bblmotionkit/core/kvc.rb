module KVC
  
  # class method to work around inexplicable state deletion issue when used as a mixin.
  # http://www.ruby-forum.com/topic/205691
  def self.make_hash_one_dimensional(input = {}, output = {}, options = {})
    input.each do |key, value|
      key = options[:prefix].nil? ? "#{key}" :
  "#{options[:prefix]}#{options[:delimiter]||"_"}#{key}"
      if value.is_a? Hash
        make_hash_one_dimensional(value, output, :prefix => key, :delimiter => ".")
      else
        output[key]  = value
      end
    end
    output
  end

end


class NSObject
  def kvc_get( key_path )
    self.valueForKeyPath(key_path)
  end
  
  def kvc_set( key_path_or_hash, val = nil )
    if key_path_or_hash.is_a? NSDictionary
      kv_hash = key_path_or_hash
      pe_debug "setting #{self} with #{kv_hash}"
      kv_hash.map do |k,v|
        self.kvc_set k, v
      end

      return
    end

    key_path = key_path_or_hash.to_s
    if val.nil?
      raise "nil value given for #{key_path}"
    end
    
    # # check for an intermediate nil.
    # key_path_segments = key_path.split('.')
    # keypath_segment = ''
    # key_path_segments[0..-2].each do |segment|
    #   keypath_segment += (key_path.empty? ? '' : '.') + segment
    #   if ! kvc_get(key_path) 
    #     pe_warn "value for key_path #{key_path} on #{self} is nil"
    #     self.setValue({}, forKeyPath:key_path)
    #   end
    # end

    pe_debug "setting #{self} #{key_path} to #{val}"
    self.setValue(val, forKeyPath:key_path)
  end

  def kvc_set_if_needed( key_path, val )
    if val != self.kvc_get(key_path)
      self.kvc_set key_path, val
    end
  end

  # def valueForUndefinedKey( key )
  # pe_warn "undefined key #{key} for #{self} - check kvc/kvo usage."
  #end
  
  def kvc_insert( collection_key, element, index = nil )
    setter_name = "insertObject:in#{collection_key.capitalize}AtIndex:"
    
    if ! index
      count_accessor = "countOf#{collection_key.capitalize}"
      index = self.send count_accessor
    end
    
    self.send setter_name, element, index
  end
  
  def kvc_remove( collection_key, element)
    setter_name = "removeObjectFrom#{collection_key.capitalize}AtIndex:"
    
    index = self.send(collection_key).index( element )
    
    self.send setter_name, index
  end
  
  def kvc_path_init( key_path )
    each_sub_key_path(key_path) do |sub_key_path|
      unless self.kvc_get sub_key_path
        debug [ sub_key_path ]
        pe_log "nil value for #{self}.#{sub_key_path}, initialising with a new hash."
        self.kvc_set sub_key_path, {}
      end
    end
  end

  
  private

  def nil_sub_key_path(key_path)
    each_sub_key_path(key_path) do |sub_key_path|
      if ! self.kvc_get sub_key_path
        return sub_key_path unless sub_key_path.eql? key_path
      end
      end
    nil
  end

  private
  
  def each_sub_key_path( key_path )
    segments = key_path.split('.')
    (segments.size - 1).times do |i|
      sub_key_path = segments[0..i].join('.')
      yield sub_key_path
    end
  end

end


  
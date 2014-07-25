module Reactive
  include BubbleWrap::KVO

  def react_to_and_init( *key_paths, &block )

    react_to *key_paths, &block

    key_paths.map do |keypath|
      value = self.kvc_get keypath
      self.kvo_change keypath, value
    end
  end
  
  def react_to( *key_paths, &block )
    key_paths.each do |key_path|
      observe self, key_path do |old_val, new_val|
        if old_val != new_val
          if Log.level == :debug
            pe_debug "#{self}.#{key_path} changed, reacting with #{new_val}"
          end
          
          begin
            block.call(new_val)
          rescue Exception => e
            pe_warn e          
          end
        end
      end
    end

  end

  def react_to_eager( *key_paths, &block )
    key_paths.each do |key_path|
      observe self, key_path do |old_val, new_val|
        if Log.level == :debug
          pe_debug "#{self}.#{key_path} changed, reacting with #{new_val}"
        end
        
        begin
          block.call(new_val)
        rescue Exception => e
          pe_warn e          
        end
      end
    end

  end

end

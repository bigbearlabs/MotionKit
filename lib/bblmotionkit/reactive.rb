module Reactive
  include BubbleWrap::KVO

  def react_to( *key_paths, &block )

    key_paths.each do |key_path|
      observe self, key_path do |k,c,ctx|
        vals = key_paths.map {|p| self.kvc_get p}
        # TODO by default, invoke only if value changed.
        pe_debug "#{self}: #{key_path} changed, reacting with #{vals}"
        
        begin
          block.call(*vals)
        rescue Exception => e
          pe_warn e          
        end
      end
    end

  end

end
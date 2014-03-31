module MsgLogging
  def method_missing(m, *args, &block)  
    puts "#{self}##{m} called with #{args}, #{block}"  
  end
end

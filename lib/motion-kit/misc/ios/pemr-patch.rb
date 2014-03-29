def pe_debug(msg)
  # pe_log msg
  puts "DEBUG: #{msg}" if $DEBUG
end

def pe_log(msg)
  puts msg
end

def pe_warn(msg)
  puts msg
end

def pe_report(*args)
  puts args
end

def debug( *args )
  pe_debug args.to_s
end



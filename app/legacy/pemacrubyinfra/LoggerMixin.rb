# use cooca lumberjack
Log = Motion::Log
Log.addLogger DDASLLogger.sharedInstance
Log.addLogger DDTTYLogger.sharedInstance

Log.level = :info


# set the LOGGING envvar to a csv of log levels to send to NSLog.
# TODO change envvar value to a csv of log module - level pairs.
module LoggerMixin
	
	logging_str = ENV['LOGGING']
	NSLog_levels = case logging_str
	when nil
		[ :warn ]
	else
		logging_str.split(',').collect { |s| s.intern }
	end

	def pe_debug( msg )
		if should_nslog :debug
			NSLog( "DEBUG: " + pe_escape_format_specifiers(msg) )
		else
			if $DEBUG
				Log.debug msg.to_s
			end
		end
	end
	
	def pe_log( msg )
		if should_nslog :info
			NSLog( pe_escape_format_specifiers(msg) )
		else
			Log.info msg.to_s
		end
	end
  
	def pe_warn( msg )
		if should_nslog :warn
			NSLog( "#{Environment.instance.isDebugBuild ? "##WARN## " : ""}#{pe_escape_format_specifiers(msg)}" )
		else 
			Log.warn msg.to_s
		end
	end

  def pe_trace(msg = nil)
  	if Environment.instance.isDebugBuild
	  	stack = $DEBUG ? caller : caller[0..2]
	    pe_log "** TRACE #{msg.to_s} ** #{stack.format_backtrace.join(" - ")}"
    end
  end


	def pe_report( exception, msg = nil )
		pe_warn "** Exception ** #{exception.inspect} #{msg ? msg : nil} ** backtrace: #{exception.report}"
		debug exception: exception
	end
	
	def pe_escape_format_specifiers(str)
    msg = str.to_s.gsub(/%+?/,"%%")
    msg
	end
  

	def should_nslog( level )
		NSLog_levels.include? level
	end
  
end


class NSObject
	include LoggerMixin
end


class NSException
	def backtrace
		if defined? super
			super
		else
			nil
		end
	end

	def report
		self.backtrace ? 
			self.backtrace.collect { |trace_elem| trace_elem.gsub(/^.*\//, '') }.join("\n") 
			: self.description + ", " + caller.to_s
	end
end

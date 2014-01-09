# use cooca lumberjack
Log = Motion::Log
Log.addLogger DDASLLogger.sharedInstance, withLogLevel:LOG_LEVEL_WARN
Log.addLogger DDTTYLogger.sharedInstance

Log.level = :info


# set the LOGGING envvar to a csv of log levels to send to NSLog.
# TODO change envvar value to a csv of log module - level pairs.
module Logging
	
	def pe_debug( msg )
		Log.debug msg.to_s
	end
	
	def pe_log( msg )
		Log.info msg.to_s
	end
  
	def pe_warn( msg, options = {})
      if options[:ticket]
        # TODO show message with ticket reporting url.
      end

			Log.warn msg.to_s
	end

  def pe_trace(msg = nil)
  	# if Environment.instance.isDebugBuild
    if RUBYMOTION_ENV == "development"
	  	stack = $DEBUG ? caller : caller[0..5]
	    pe_log "** TRACE #{msg.to_s} ** #{stack.format_backtrace.join(" - ")}"
    end
  end


	def pe_report( exception, msg = nil )
		pe_warn "** Exception ** #{msg ? msg : nil} ** #{exception.inspect} #{exception.description}** backtrace: #{exception.report}"
		debug exception: exception
	end
	
	def pe_escape_format_specifiers(str)
    msg = str.to_s.gsub(/%+?/,"%%")
    msg
	end
  
end


class NSObject
	include Logging
end

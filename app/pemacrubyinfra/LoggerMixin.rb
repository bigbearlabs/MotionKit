# require "logger"
class StubLogger
	DEBUG = :DEBUG

	attr_accessor :level

	def initialize(io)
	  @io = io

	  self.level = DEBUG
	end

	def info msg
		puts msg
	end

	alias_method :debug, :info
	alias_method :warn, :info

end

# set the LOGGING envvar to a csv of log levels to send to NSLog.
# TODO change envvar value to a csv of log module - level pairs.
module LoggerMixin
	
	NSLog_levels = case ENV['NSLog_levels']
	when nil
		[ :warn ]
	else
		ENV['NSLog_levels'].split(',').collect { |s| s.intern }
	end

	$pe_logger = StubLogger.new(STDOUT)
	$pe_logger.level = StubLogger::DEBUG

	def pe_debug( msg )
		if should_nslog :debug
			NSLog( "DEBUG: " + pe_escape_format_specifiers(msg) )
		else
			if $DEBUG
				$pe_logger.debug msg
			end
		end
	end
	
	def pe_log( msg )
		if should_nslog :info
			NSLog( pe_escape_format_specifiers(msg) )
		else
			$pe_logger.info msg
		end
	end
  
	def pe_warn( msg )
		if should_nslog :warn
			NSLog( "## WARNING ##: #{pe_escape_format_specifiers(msg)}" )
		else 
			$pe_logger.warn msg
		end
	end

  def pe_trace(msg = nil)
  	stack = $DEBUG ? caller : caller[0..2]
    pe_log "** TRACE #{msg.to_s} ** #{stack.format_backtrace.join(" - ")}"
  end


	def pe_report( exception, msg = nil )
		pe_warn "** Exception ** #{exception.inspect} #{msg ? msg : nil} ** backtrace: #{exception.report}"
		breakpoint exception: exception
	end
	
	def pe_escape_format_specifiers(str)
    msg = str.to_s.gsub(/%+?/,"%%")
    msg
	end
  

	def should_nslog( level )
		NSLog_levels.include? level
	end
  
end

class Exception
	def report
		self.backtrace ? self.backtrace.collect { |trace_elem| trace_elem.gsub(/^.*\//, '') }.join("\n") : nil
	end
end

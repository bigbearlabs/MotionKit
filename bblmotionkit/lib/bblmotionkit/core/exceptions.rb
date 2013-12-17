module ExceptionHandling

  def handle_exceptions( &handler )
    handler ||= -> exception, mask {
      pe_warn "#{exception} occurred."
    }

    NSExceptionHandler.defaultExceptionHandler.setExceptionHandlingMask(
      NSLogUncaughtExceptionMask | NSHandleUncaughtExceptionMask |
      NSLogUncaughtSystemExceptionMask | NSHandleUncaughtSystemExceptionMask |
      NSLogUncaughtRuntimeErrorMask | NSHandleUncaughtRuntimeErrorMask |
      NSLogTopLevelExceptionMask | NSHandleTopLevelExceptionMask |
      NSLogOtherExceptionMask | NSHandleOtherExceptionMask
      )
    # FIXME this results in duplicate logging.

    NSExceptionHandler.defaultExceptionHandler.delegate = self

    # installing on NSApp looks unnecessary.
    # @exception_handler = handler
    # NSApp.exceptionHandler(@exception_handler, shouldHandleException)
  end

  def exceptionHandler(handler, shouldLogException:exception, mask:mask)
    # @exception_handler.call exception, mask

    # return false

    # log.
    pe_warn exception.symbolised_stack_trace

    false
  end

end

class NSException
  def backtrace
    if defined? super
      super
    else
      self.symbolised_stack_trace
    end
  end

  def report
    self.backtrace ? 
      self.backtrace.collect { |trace_elem| trace_elem.gsub(/^.*\//, '') }.join("\n") 
      : self.description + ", " + caller.to_s
  end

  def symbolised_stack_trace
    addresses = self.callStackReturnAddresses
    addresses = addresses.map{|e| e.to_s(16)}  # convert to hex
    `atos -p #{NSApp.pid} #{addresses.join ' '}`
  end
end

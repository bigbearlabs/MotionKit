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
    pe_report exception

    false
  end

end

class NSException
  def backtrace
    if defined? super
      super
    else
      self.symbolised_stack_trace.split '\n'
    end
  end

  def report
    backtrace = caller.to_a.join "\n"
    if bt = self.backtrace
      backtrace + "\n:::" + bt.join("\n")
    end

    # seems obsolete now.
    # self.backtrace.collect { |trace_elem| trace_elem.gsub(/^.*\//, '') }.join("\n") 
    # : ''

    self.description.to_s + "\n" + backtrace
  end

  def symbolised_stack_trace
    addresses = self.callStackReturnAddresses
    if RUBYMOTION_ENV == 'development'
      addresses = addresses.to_a.map{|e| e.to_s(16)}  # convert to hex
      `atos -d -p #{NSApp.pid} #{addresses.join ' '}`
    else
      addresses
    end
  end
end

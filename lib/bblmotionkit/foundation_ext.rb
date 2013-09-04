# stub

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


class NSThread
  def self.is_main?
    self.currentThread == NSThread.mainThread
  end
end


class NSTimer
  def self.new_repeating_timer( interval, &action )
    action_holder = ProcRunner.new -> {
      pe_debug "#{self}: interval reached, yielding to block"
      action.call
    }

    timer = self.scheduledTimerWithTimeInterval(interval, target:action_holder, selector: 'perform_proc', userInfo:nil, repeats:true)

    NSRunLoop.currentRunLoop.addTimer(timer, forMode:NSDefaultRunLoopMode)

    timer
  end
end


# from Execution.rb

def on_main_async( &block )
  Dispatch::Queue.main.async do
    block.call
  end
end

class ProcRunner
  attr_reader :result
  attr_reader :exception

  def initialize( proc, desc = nil )
    super

    @proc = proc
    @desc = desc
    @desc ||= proc.to_s
  end

  def perform_proc( stub_proc = nil )
    thread_desc = NSThread.is_main? ? 
      "main thread" :
      NSThread.currentThread.inspect
    pe_debug "running proc #{@desc} on #{thread_desc}, backtrace: #{caller[0..3].format_backtrace}" if $DEBUG

    @result = @proc.call
    
  rescue Exception => e
    pe_report e
    @exception = e
  end
end


class NSURL
  def last_path_segment
    segments = self.path.split('/')
    segments ? segments.last : nil

  end
end


#= plain old ruby stuff. REFACTOR

class Fixnum
  def to_s_leading_zero
    "%02d" % self
  end
end
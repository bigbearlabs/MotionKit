#
#  Execution.rb
#  WebBuddy
#
#  Created by Park Andy on 17/02/2012.
#  Copyright 2012 __MyCompanyName__. All rights reserved.
#


# invoke block on main thread
def on_main( &block )
  originating_trace = $DEBUG ? caller : nil
  # check if main thread and just perform if it is.
  result = nil
  if NSThread.is_main?
    result = block.call
  else
    # Dispatch::Queue.main.sync do
    #   begin
    #     result = block.call
    #   rescue Exception => e
    #     pe_report e, originating_trace
    #     raise e
    #   end
    # end

    @runners_on_main ||= []
    runner = ProcRunner.new -> {
      block.call
      @runners_on_main.delete runner
    }
    @runners_on_main << runner

    runner.performSelectorOnMainThread('perform_proc:', withObject:nil, waitUntilDone:true)
  end

  return result
end

def on_main_async( &block )
  # NOTE several attempts to log stack trace at dispatch request didn't work in motion.
  # queuer = nil
  # begin
  #   raise "stub"
  # rescue Exception => e
  #   queuer = e.backtrace
  # end

  queuer = NSThread.callStackSymbols  # badly formatted RM symbols
  queuer = caller  # empty in RM (sometimes?)

  Dispatch::Queue.main.async do
    begin
      block.call
    rescue Exception => e
      pe_report e, "executing #{block} , trace on dispatch: #{queuer}"
    end
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


def concurrently( lambda, completion_lambda = nil )
  Dispatch::Queue.concurrent.async do
    begin
      lambda.call
    ensure
      completion_lambda.call if completion_lambda
    end
  end
end

def periodically(interval = 5, delay = 0, leeway = 0.5, &block)
  @periodically_queue ||= Dispatch::Queue.new('periodically')
  timer = Dispatch::Source.timer(delay, interval, leeway, @periodically_queue) do |s|
    pe_debug "timer source."
    block.call s
  end
  timer
end


# wraps selector invocation queuing / cancelling.
# TODO make requests queued up per a specified key, defaulting to something unique to the proc. currently too coarse-grain.
class NSObject
  def run_proc( proc )
    proc.call
  end

  def delayed( delay, proc )
    pe_debug "queuing #{proc}"
    self.performSelector('run_proc:', withObject:proc, afterDelay:delay)
  end

  def cancel_procs
    pe_debug "cancelling all perform requests for target #{self}"
    self.class.cancelPreviousPerformRequestsWithTarget(self)
  end
  
  def delayed_cancelling_previous( delay, proc )
    self.cancel_procs
    self.delayed delay, proc
  end
end


# NOTE seems redundant given the above.
class DelayedExecution
  @@queue = Dispatch::Queue.new(self.class.name)

  attr_reader :delay
  
  def initialize(delay, proc)
    
    pe_log "execute #{proc} after #{delay}"
    
    # @timer = NSTimer.scheduledTimerWithTimeInterval(delay, target:self, selector:'run_proc:', userInfo:nil, repeats:false)
    @@queue.after(delay) {
      # invoke after @delay
      proc.call
    }
  end
  
  def cancel # IMPL
  end
  
end


# synchronisation on this class looks wonky.
class LastOnlyQueuer
  attr_accessor :counter
  attr_accessor :work_queue
  
  def initialize(name)
    super()
    @name = name
    
    @last_only_sync_queue = Dispatch::Queue.new("#{self.class.name}.#{name}.serialisation")
    @counter_queue = Dispatch::Queue.new("#{self.class.name}.#{name}.counter")
    @work_queue = Dispatch::Queue.new("#{self.class.name}.#{name}.work")
    
    self.counter = 0
  end
  
  def async_last_only(&block)
    # establish a mutually exclusive section for the main logic of this class.
    @last_only_sync_queue.async {
      @counter_queue.async { # NOTE ?? looks broken.
        self.increment
       
        pe_debug "#{self} queue count incremented to #{self.counter}"

        # queue block on the work queue. if jobs build up on the work queue, counter will exceed 1 and the earlier jobs will be skipped.
        @work_queue.async {
          
          # skip if counter > 1, else call the block 
          if self.counter > 1
            pe_log "#{self} counter==#{self.counter}, skipping"
          else
            begin
              pe_debug "#{self} running #{block}"
              block.call
            rescue Exception => e
              pe_debug "#{self} exception running #{block} : #{e.to_s}"
            end
          end

          pe_debug "#{self} queue count pre-decrement: #{self.counter}"
          self.decrement
        }
      }
    }
  end
  
  def increment
      self.counter += 1
  end
  
  def decrement
      self.counter -= 1
  end
end


# yet another version of a queue that discards all queued operations for a semantically 'latest' operation.
class TicketBasedQueuer

  def initialize(name)
    super()
    @name = name
    
    @synchronisation_queue = Dispatch::Queue.new("#{self.class.name}.#{name}.synchronisation")
    @work_queue = Dispatch::Queue.new("#{self.class.name}.#{name}.work")
  end

  def async_with_ticket(ticket, &proc)
    @synchronisation_queue.async {
      @ticket = ticket.to_s
      ticket_for_job = ticket.to_s.dup
      
      @work_queue.async {
        if ticket_for_job != @ticket
          pe_log "ticket expired (current:#{@ticket}, mine:#{ticket_for_job}), skipping #{proc}."
        else
          proc.call
        end
      }
    }
  end
end


class FirstOnlyQueuer
  def initialize(name)
    super
    @name = name

    @work_queue = Dispatch::Queue.new(name + ".work")
  end

  def async_first_only(&block)
    # wrap the block with an operation that flags and works, or exits if flag already on.
    op = -> {
      if ! @working
        @working = true
        yield
        @working = false
      else
        pe_log "#{self} has work, skipping #{block.to_s}"
      end
    }

    # serialise execution of op onto a queue, thus guaranteeing atomic flagging of @working.
    @work_queue.async {
      op.call
    }
  end
end


class NSThread
  def self.is_main?
    self.currentThread == NSThread.mainThread
  end
end
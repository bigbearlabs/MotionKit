class RubyEvalPlugin < WebBuddyPlugin
  attr_accessor :input

  def on_setup
    @eval_reaction = react_to :input do |input|
      on_input input if input
    end
  end

  def on_input( input )
    self.load_view unless view_loaded?
    self.show_plugin

    self.update_input input
  end

  def update_input input
     @input = input
     @output = do_eval input

     update_data self.data
  end 

  def do_eval( expr )
    eval input
  rescue Exception => e
    e
  end
  
  #=

  def name
    'eval'
  end

  def data
    {
      input: @input.to_s,
      output: @output.to_s
    }
  end
  
end
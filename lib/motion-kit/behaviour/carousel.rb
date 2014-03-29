## define a simple state machine for cycling behaviour. 
## first target: cycle cmd-f
## retrofit: switcher plugin.

class Carousel
  # example of states:
  # {
  #   states: [ :state1, :state2, :state3 ]
  #   proto: {
  #     next: -> states, i {
  #       states[i+1]
  #     },
  #     previous: -> states, i {
  #       states[i-1]
  #     }
  #   }
  # }

  attr_reader :state

  def initialize(states, initial_state = states[0])
    @states = states

    @initial_state = initial_state
  end

  def next
    if @state.nil?
      @state = @initial_state
    else
      next_state = @states[state_index + 1]
      next_state ||= @states.first
      @state = next_state
    end

    pe_log "state for #{self} set to #{@state}"
    
    @state.call
  end

  def previous
  end


  def state_index
    @states.index @state
  end

end

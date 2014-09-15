motion_require '../core/reactive'

## define a simple state machine for cycling behaviour. 
## first target: cycle cmd-f
## retrofit: switcher plugin.

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
class Carousel
  include Reactive  

  attr_reader :current_state


  # client_observation_spec e.g.: 
  # {
  #   sync_target: client
  #   key_path: 'property',
  #   when: expr,
  #   state: state
  # }
  def initialize(state_handlers_by_state, initial_state = states[0], client_observation_spec = nil
    )
    @states = state_handlers_by_state
    @initial_state = initial_state
    @current_state = @initial_state

    # # observe client to synchronise state.
    # if client_observation_spec
    #   observe_kvo client_observation_spec[:sync_target], client_observation_spec[:key_path] do |object, change, context|
    #     p "change: #{change}"
    #     if change.kvo_new.eql? client_observation_spec[:when]
    #       self.update_state client_observation_spec[:state]
    #     end
    #   end
    # end

    p "carousel initialised."
  end

  def sync_state(obj, key_path, &value_transformer)
    @obj = obj
    react_to "obj.#{key_path}" do |new_val|
      update_state value_transformer.call(new_val)
    end
  end
  


  def next
    # update current state.
    next_state = @states.keys[state_index + 1] || @states.keys.first
    @current_state = next_state

    pe_log "state for #{self} set to #{@current_state}"
    
    @states[@current_state].call
  end

  def previous
  end


  private
    attr_reader :obj  # for kvo

    # method for state synchronisation with a collaborator. bypasses state transition methods.
    def update_state(new_state)
      @current_state = new_state
    end
    
    def state_index
      @states.keys.index @current_state
    end

end

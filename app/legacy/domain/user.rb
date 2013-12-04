# FIXME context is view-specific - visit all usages and replace with an alternative.
# NOTE can fix by observing notifications rather than requiring calls.

class User
  attr_reader :actions

  attr_accessor :context

  def initialize
    super
    
    @actions = []
    @filters = [] # probably redundant with the intro of tracks.
  end
    
#= quick access to current state.
# REFACTOR this is a redundant aspect - just rely on the data facade for this stuff.

  def page
    @context.current_history_item
  end
  
  def site
    @context.current_site
  end
  
  def default_site
    @context.site_for('http://www.google.com')
  end
  
#= user's inputs.
  
  def filter
    @filters.last
  end

#= methods representing user actions to app

  def perform_activation( activation_params )
    send_notification :Activation_notification, activation_params
  end

  def perform_deactivation
    send_notification :Deactivation_notification
  end
    
#= REFACTOR inline, as already abstracted well. 

  def perform_filter(filter_string)
    pe_debug caller

    action = FilterAction.new(filter_string)
    self.add_action action

    filter_spec = FilterSpec.new(:recent_first, action.filter_string, self.page)
    # self.update_filter_spec filter_spec
  end
  
  def perform_unfilter
    action = UnfilterAction.new
    self.add_action action

    # filter_spec = FilterSpec.new(:recent_last, nil, self.page)
    filter_spec = FilterSpec.new(:recent_first, nil, self.page)
    self.update_filter_spec filter_spec
  end

  # represents a click on a stack item.
  def perform_stack_navigation(info)
    url = info[:destination].to_url_string
    stack_id = info[:stack_id]
    action = Revisit.new(url, stack_id)
    self.add_action action

    # we want to checkpoint the current filter.
    send_notification :Revisit_request_notification, action
  end
  
  def perform_link_navigation(url)
    # user clicked a link.
    
    send_notification :Link_navigation_notification, url: url
    
    # we might want to consult policy on what other domain-level side effects should occur.
  end
    
  def perform_url_input(url)
    visit = Visit.new(url)
    self.add_action visit

    predicate_input_string = self.filter ? self.filter.predicate_input_string : ''
    filter_spec = FilterSpec.new(:recent_first, predicate_input_string)
    self.update_filter_spec filter_spec

    # send notification.
    send_notification :Visit_request_notification, url
    
    # TODO replace all load_request_notifications with visit notification.
  end
  
  def perform_search( search_input, site = self.default_site )
    search_action = SearchAction.new(search_input)
    self.add_action search_action

    search_url = site.search_url.to_query_url search_input

    send_notification :Site_search_notification, 
      query: search_input,
      url: search_url
  end
  
  def perform_site_search( search_input )
    if self.site && self.site.searchable?
      perform_search search_input, self.site
    else
      # when current site invalid, fall back to default.
      perform_search search_input, default_site
    end
  end
  
#=

  def perform_url_invocation( url, originating_process_name )
    # TODO
  end


  # TODO gesture navigation


#=

  def update_filter_spec(filter_spec)    
    send_notification :Filter_spec_updated_notification, filter_spec
    
    self.add_filter( filter_spec )
  end

  def add_action( action )
    @actions << action
  end
  
  def add_filter( filter_spec )
    @filters << filter_spec
  end

end


class Array
  def push_or_update( item )
    existing_item = self.select { |element| element.matches(item) }
    
    if existing_item
      # assume no dupes.
      self.move_to_tail( self.index(existing_item) )
    else
      self << item
    end
  end
  
  def move_to_tail(index)
    self.insert(self.size - 1, self.delete_at(index))
  end
end
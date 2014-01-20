class FilteringPlugin < WebBuddyPlugin
  include Reactive

  attr_accessor :context_store

  def on_setup
    unless @server_registered
      NSApp.delegate.component(ServerComponent).add_handler '/data', :GET do |request, response|
        on_request request, response
      end

      @server_registered = true
    end

    @input_reaction = react_to 'client.input_field_vc.current_filter' do |input|
      on_input input if input
    end

    @update_data_reaction = react_to 'client.stack.pages' do
      update_data searches_delta: data_searches( [ self.client.stack ])
    end

    # set up a policy on the web view delegate to prevent href navigation.
    @set_policies_reaction = react_to 'client.plugin_vc.web_view_delegate' do |delegate|
      delegate.policies_by_pattern = {
        %r{localhost|WebBuddy/plugins|WebBuddy.app/Contents/Resources/plugins} => :load,
        %r{(http://)?about:} => :load,
        /.+/ => -> url, listener {
          pe_log "policy will send #{url} to client."
          
          pe_warn "#{self}"
          on_web_view_nav url

          listener.ignore
        },
      }
    end

    load_view
  end
  
  # FIXME why doesn't this work on FilteringPlugin ?
  def on_web_view_nav( url )
    # stack_id = selected_item_data[:name]
    stack_id = Object.from_json(self.selected_item_data)['name']

    # load url in the client. 
    self.client.load_url url, stack_id: stack_id
  end  


  def on_input input
    # HACK work around lack of navigability constraint.
    self.load_view unless view_loaded? 
  
    self.show_plugin

    self.update_input input
  end

  def update_input input
    @input = input
    
    update_data input:@input
  end

  #= view-layer operations

  # get the stack based on the view model.
  def selected_item_data
    self.client.plugin_vc.eval_expr %q(
      angular.element('.detail').scope().view_model.selected_item
    ), :get_selected_item
  end
  
  def fetch_data
    self.client.plugin_vc.eval_expr %q(
      angular.element('.detail').scope().fetch_data()
    ), :fetch_data
  end
  
  #=

  def data
    {
      input: @input ? @input : '',

      searches: data_searches,

      # pages: data_pages,

      # http://suggestqueries.google.com/complete/search?output=toolbar&hl=ja&q=keyword
      suggestions: 
        [
          1,2,3
        ],

      highlights: 
        [
          "... some template text here WITH HIGHLIGHT and other text...",
          "... other text WITH HIGHLIGHT and more related text..."
        ]
    }
  end

  def data_searches( stacks = @context_store.stacks )
    stacks_data = stacks.map do |stack|
      data_stack stack
    end
  end

  def data_stack( stack )
    pages = stack.pages
      .select { |e| ! e.provisional }

    stack_url = pages.empty? ? '' : pages.first.url

    {
      name: stack.name,
      # thumbnail_url: 'stub-thumbnail-url',
      url: stack_url,
      last_accessed_timestamp: stack.last_accessed_timestamp.to_s,
      pages: 
        pages.map do |page|
          {
            name: page.title,
            url: page.url,
            thumbnail_url: @context_store.thumbnail_url(page).to_url_string
          }
        end
    }
  end
  
  
  def data_pages
    # quickly hack out a union of all items
    all_items = @context_store.stacks.map(&:items).flatten.uniq

    all_items.map do |item|
      {
        name: item.title,
        url: item.url,
        thumbnail_url: @context_store.thumbnail_url(item).to_url_string
      }
    end
  end
  
  #=

  def on_request( request, response )
    pe_log 'filtering request received'

    response.respondWithString self.data.to_json
  end
  
end



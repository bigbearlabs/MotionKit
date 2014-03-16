class FilteringPlugin < WebBuddyPlugin
  include Reactive

  attr_accessor :context_store

  def on_setup
    setup_server

    @input_reaction = react_to 'client.input_field_vc.current_filter' do |input|
      on_input input if input
    end

    # react_to 'context_store.updated_stack' do |updated_stack|
    # WORKAROUND kvo -> nil ivar bug
    NSApp.delegate.react_to 'updated_stack' do |updated_stack|
      on_updated_stack updated_stack
    end

    # set up a policy on the web view delegate to prevent href navigation.
    set_policy = -> delegate {
      delegate.policies_by_pattern = {
        /.+/ => -> url, listener {
          pe_log "nav request #{url} from plugin_vc."
          
          listener.use
        },
      }    
    }
    if delegate = client.plugin_vc.web_view_delegate
      set_policy.call delegate
    else
      react_to 'client.plugin_vc.web_view_delegate' do |delegate|
        set_policy delegate
      end
    end
    # init.
    # client.plugin_vc.web_view_delegate = client.plugin_vc.web_view_delegate

    load_view
  end
  
  #= web -> native

  # TODO generalise web -> native calling mechanism, log around.

  def on_input_field_submit( input )
    input_vc = self.client.input_field_vc
    
    input_vc.input_text = input
    input_vc.handle_field_submit self
  end

  def on_item_click( item )
    client.load_url item.kvc_get :url
  end
  
  # TODO abstract.
  def self.isSelectorExcludedFromWebScript(sel)
    puts "webview enquiring on sel: #{sel}"
    if [ 'on_input_field_submit:', 'on_item_click:' ].include? sel.to_s
      false
    else
      true
    end  
  end
      
  #= native -> web

  def on_input input
    # HACK work around lack of navigability constraint.
    self.load_view unless view_loaded? 
  
    self.show_plugin

    @input = input
    
    update_data input:@input
  end

  def on_updated_stack stack
    pe_log "sending updated stack #{stack} to filtering plugin"
    update_data searches_delta: data_searches([ stack ])
  end
  

  #= view-layer operations. experimental
  
  def fetch_data
    self.client.plugin_vc.eval_expr %q(
      angular.element('.app-view').scope().fetch_data()
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

#= TODO refactor as feature strategies

  def data_searches( stacks = @context_store.stacks )
    stacks.map do |stack|
      stack.to_hash
    end
  end
  
  
  def data_pages
    # quickly hack out a union of all items
    all_items = @context_store.stacks.map(&:items).flatten.uniq

    all_items.map do |item|
      {
        name: item.title,
        url: item.url,
        thumbnail_url: @context_store.thumbnail_url(item)
      }
    end
  end
  
  #=

  def setup_server
    # unless @server_registered
      server = NSApp.delegate.component(ServerComponent)

      server.add_handler '/plugins/data/filtering.json', :GET do |request, response|
        on_request request, response
      end

      @server_registered = true
    # end
  end
  
  def on_request( request, response )
    pe_log 'filtering request received'

    pe_trace  # seems to be looping: why?
    
    # TODO when method is put, update store with potentially tainted data.
    pe_log "request: #{request.body.to_str}"

    response.setHeader("Content-Type", value:"text/plain")
    # response.respondWithData(self.data.to_json)
    # work around strange nsstring -> nil nsdata for large strings by going through a unicode encoding.
    response.respondWithData(self.data.to_json.to_encoded_data(NSUnicodeStringEncoding))

    pe_log 'served filtering request'
  end

#= input field

  def focus_input_field
    self.show_plugin
    
    eval_js %Q(
      angular.element('.app-view').scope().focus_input_field()
    )

    # hackily perform native op for focus
    client.plugin_vc.web_view.make_first_responder

  end


end


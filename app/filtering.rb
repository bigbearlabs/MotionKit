# TODO need to ensure the view doesn't load another url. how to best facilitate?
class FilteringPlugin < WebBuddyPlugin
  include Reactive

  def on_setup
    @filter_reaction = react_to 'client.input_field_vc.current_filter' do |input|
      on_input input if input
    end

    @update_delta_reaction = react_to 'client.stack', 'client.stack.pages' do
      pe_log "reacting to stack / page update."
      update_data searches_delta: data_searches( [ self.client.stack ])
    end
  end

  def load_view
    super -> {
      self.update_data
    }
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

  #=

  def data
    {
      input: @input ? @input : '',

      searches: data_searches,

      pages: data_pages,

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
    stacks_data = stacks.sort_by {|e| e.last_accessed_timestamp.to_s}.reverse.map do |stack|
      data_stack stack
    end

    Hash[ stacks_data.map {|e| [ e[:name], e ]} ]
  end

  def data_stack( stack )
    pages = stack.pages
      .select { |e| ! e.provisional }
      .sort_by {|e| e.last_accessed_timestamp.to_s}.reverse

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
  
end
class FilteringPlugin < WebBuddyPlugin
  include Reactive

  def on_setup
    react_to 'client.input_field_vc.current_filter' do |input|
      self.show_plugin

      self.update_data  # TACTICAL need to react to changes to context_store.

      self.update_input input
    end

    self.load_view
  end


  def update_input input
    @input = input
    self.client.plugin_vc.web_view.delegate.send %(
      window.webbuddy_data.input = #{input.to_json};
      window.webbuddy_data_updated();  // will throw if callback 
    )
  end

  #=

  def data
    context_store = @context_store
    return {} if context_store.nil?

    # quickly hack out a union of all items
    all_items = context_store.stacks.map{|e| e.history_items}.flatten.uniq

    {
      input: @input,
      searches: 
        context_store.stacks.sort_by {|e| e.last_accessed_timestamp }.reverse.map do |stack|
          pages = stack.history_items.sort_by {|e| e.last_accessed_timestamp}.reverse

          stack_url = pages.empty? ? '' : pages.first.url

          {
            name: stack.name,
            # thumbnail_url: 'stub-thumbnail-url',
            url: stack_url,
            last_accessed_timestamp: stack.last_accessed_timestamp,
            pages: 
              pages.map do |page|
                {
                  name: page.title,
                  url: page.url,
                  thumbnail_url: context_store.thumbnail_url(page).to_url_string
                }
              end
          }
        end,
      pages: 
        all_items.sort_by {|e| e.last_accessed_timestamp}.reverse.map do |item|
          {
            name: item.title,
            url: item.url,
            thumbnail_url: context_store.thumbnail_url(item).to_url_string
          }
        end,
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

end
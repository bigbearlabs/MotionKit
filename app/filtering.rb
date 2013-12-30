# TODO need to ensure the view doesn't load another url. how to best facilitate?
class FilteringPlugin < WebBuddyPlugin
  include Reactive

  def on_setup
    @filter_reaction = react_to 'client.input_field_vc.current_filter' do |input|
      on_input input if input
    end

    self.load_view
  end

  def on_input input
    # HACK work around lack of navigability constraint.
    self.load_view unless view_loaded? 
  
    self.show_plugin

    self.update_input input
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
    all_items = context_store.stacks.map(&:items).flatten.uniq

    {
      input: @input ? @input : '',
      searches: 
        context_store.stacks
          .sort_by {|e| e.last_accessed_timestamp }.reverse.map do |stack|

          pages = stack.pages
            .select { |e| ! e.provisional }
            .sort_by {|e| e.last_accessed_timestamp}.reverse

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
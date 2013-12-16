# a spec for filtering.
class FilterSpec
  attr_reader :sort # RENAME sorting
  attr_accessor :predicate_input_string  # RENAME query
  attr_reader :selected_object  # RENAME selected_item
  attr_reader :limit_direction
  
  def initialize(sort, predicate_input_string, selected_object = nil)
    # @sort = sort  # disable unstable reordering behaviour.
    @sort = :recent_first
    @predicate_input_string = predicate_input_string
    @selected_object = selected_object
    @limit_direction = 
      case sort
      when :recent_last then :tail
      when :recent_first then :head
      else
        raise "unknown sorting #{sort}"
      end
  end
end


## integration
class FilteringPlugin < WebBuddyPlugin

  def setup
    watch_notification :Filter_spec_updated_notification
  end

  def handle_Filter_spec_updated_notification( notification )
    filter_spec = notification.userInfo

    filter filter_spec
  end

  # TODO fix leaky abstraction with filter_spec.
  def filter( filter_spec )
    @filter_spec = filter_spec
    self.load_filtering filter_spec.predicate_input_string
    # DEV FIXME replace with load_view
  end

  def load_filtering( input )
    pe_log "filtering for #{input}"

    on_main_async do
      if view_loaded?
        self.update_input input
      else
        self.load_view do
          self.update_data
          # self.update_input input
        end
      end
    end
  end

  def update_input input
    NSApp.delegate.wc.browser_vc.web_view.delegate.send "webbuddy.module.update_property('input', #{input.to_json});"
  end

  #=

  def data
    context_store = @context_store
    return {} if context_store.nil?

    # quickly hack out a union of all items
    all_items = context_store.stacks.map{|e| e.history_items}.flatten.uniq

    {
      input: @filter_spec.predicate_input_string,
      searches: 
        context_store.stacks.sort_by {|e| e.last_accessed_timestamp }.reverse.map do |stack|
          pages = stack.history_items.sort_by {|e| e.last_accessed_timestamp}.reverse

          stack_url = pages.empty? ? '' : pages.first.url
          {
            name: stack.name,
            # thumbnail_url: 'stub-thumbnail-url',
            url: stack_url,
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
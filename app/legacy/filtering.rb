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

class HistoryTrackSpec < FilterSpec
  def initialize
    # super(:recent_last, '')
    super(:recent_first, '')
  end
end


## integration
module Filtering
  def filter filter_spec
    puts "filtering..."
    @filter_spec = filter_spec
    self.load_filtering filter_spec.predicate_input_string
    # DEV FIXME replace with load_module
  end

  def filtering_data
    # REFACTOR
    context_store = $appd.instance_variable_get(:@context_store)
    return {} if context_store.nil?

    {
      input: @filter_spec.predicate_input_string,
      searches: 
        self.context.tracks.sort_by {|e| e.last_accessed_timestamp}.reverse.map do |track|
          pages = track.history_items.sort_by {|e| e.last_accessed_timestamp}.reverse

          {
            name: track.name,
            # thumbnail_url: 'stub-thumbnail-url',
            url: pages.first.url,
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
        self.context.history_items.sort_by {|e| e.last_accessed_timestamp}.reverse.map do |item|
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

  def load_filtering( input )
    pe_log "filtering for #{input}"

    if module_loaded? :filtering
      self.update_input input
    else
      self.load_module :filtering do
        self.update_input input
      end
    end

  end

  def update_input input
    # update window.data for the web component to use.
    eval_js %(
      // setTimeout( function() {
        webbuddy.module.data.input = #{input.to_json};
        var scope = webbuddy.module.filter_scope;
        scope.refresh_data();
        scope.$apply();
      // }, 100);
    )

    debug
  end

  #=

  def write_data
    # # write to data/filtering.json TODO fix up prior to release.
    # data_path = NSBundle.mainBundle.path + "/#{module_dir}/data/filtering.json"  # DEPLOY
    data_path = '/Users/ilo-robbie/dev/src/bigbearlabs/webbuddy-modules/output/app/data/filtering.json'  # DEV
    write_file data_path, self.data.to_json  # FIXME this races with the load on filtering.coffee
  end
  
  def load_module module_name

    # self.write_data

    load_location self.module_url, -> {
      self.attach_hosting_interface

      yield if block_given?
    }, ignore_history: true
  end

  def attach_hosting_interface
    # IMPROVE load from a module file.
    eval_js %(
      // if (!window.webbuddy)
      //   //throw "window.webbuddy already set!"
      //   window.webbuddy = {
      //     module: {}
      //   };

      // window.webbuddy.env = {
      //   name: 'webbuddy'
      // };
      // window.webbuddy.log = function() {};
      // window.webbuddy.module.data = {
      //   data: //{self.data.to_json}
      // };

      // return webbuddy;

      window.webbuddy = {
        env: {
          name: 'webbuddy'
        },
        log: function() {},
        module: {
          data: #{self.data.to_json}
        }
      };

      return webbuddy;
    )

    # debug eval_js 'return webbuddy.env.name'
  end

  #= module

  def data
    # REFACTOR move method.
    window_controller = self.view.window.windowController
    data = window_controller.filtering_data
  end
  
  def update_data data
    pe_log "updating data, keys: #{data.keys}"

    eval_js %(
      return webbuddy.module.update_data(#{data.to_json});
    )
  end

  def module_loaded? module_name
    self.module_url and self.url.to_s.include? self.module_url  # FIXME this doesn't work when reloading the module.
  end

  def module_url
    # @module_url ||= 
      # 'http://localhost:9000/#/filtering'  # DEV

    module_dir = "modules/output"
    module_index_path = NSBundle.mainBundle.url("#{module_dir}/index.html").path
    @module_url ||= module_index_path + '#/filtering'  # DEPLOY
  end
  
end
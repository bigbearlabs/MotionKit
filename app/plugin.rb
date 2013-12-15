# plugin loaded by AppD, but interacts with wc a lot -- this probably indicates a granularity mismatch.
class WebBuddyPlugin < BBLComponent
  extend Delegating
  def_delegator :'client.wc.browser_vc', :eval_js, :eval_expr

  include IvarInjection
  
  def initialize(client, deps = {})
    super client

    inject_collaborators deps
  end

  def view_url
    plugin_name = self.class.name.gsub('Plugin', '').downcase
    
    @view_url = "http://localhost:9000/#/#{plugin_name}"  # DEV

    # plugin_dir = "plugin/output"
    # module_index_path = NSBundle.mainBundle.url("#{plugin_dir}/index.html").path
    # @view_url = module_index_path + "#/#{plugin_name}"  # DEPLOY
  end
  
  def load_view(&load_handler)
    # self.write_data

    client.wc.load_url self.view_url, success_handler: -> url {
      self.attach_hosting_interface

      # on_main_async do
        # yield if block_given?
        load_handler.call
      # end
    }
    # , ignore_history: true
  end

  def view_loaded?
    self.client.wc.browser_vc.url.to_s.include? self.view_url
  end

  # creates the window.webbuddy property.
  # FIXME sometimes this can get clobbered by the stub if it doesn't attach quickly enough.
  def attach_hosting_interface
    pe_log "attaching hosting interface to #{self.view_url}"

    # eval_js_file 'plugin/assets/js/webbuddy.attach.js'

    eval_js %q(
      window.webbuddy || (window.webbuddy = {
        env: {
        },
        log: function() {},
        module: {}
      });
      webbuddy.env.name = 'webbuddy';
      return webbuddy
    )
    # pe_log "eval webbuddy.env: #{self.client.wc.browser_vc.eval_expr 'window.webbuddy'}"
  end

  def update_data
    data = self.data
    pe_log "updating data, keys: #{data.keys}"

    # eval_js %(
    #   return webbuddy.module.update_data(#{self.data.to_json});
    # )

    eval_js %(
      if (! webbuddy || ! webbuddy.module)
        throw "webbuddy.module not available."

      webbuddy.module.data = #{data.to_json};
      // trigger view refresh if needed
      // if (webbuddy.module.scope)
        webbuddy.module.scope.refresh_data();
        webbuddy.module.scope.$apply();
        // webbuddy.module.scope.filter(); # LEAKY
    )
  end

  # OBSOLETE
  def write_data
    # # write to data/filtering.json TODO fix up prior to release.
    # data_path = NSBundle.mainBundle.path + "/#{module_dir}/data/filtering.json"  # DEPLOY
    data_path = '/Users/ilo-robbie/dev/src/bigbearlabs/webbuddy-plugin/output/app/data/filtering.json'  # DEV
    write_file data_path, self.data.to_json  # FIXME this races with the load on filtering.coffee
  end
  
  #=

  def inspect_data
    puts Object.from_json( eval_expr 'webbuddy.module.data').description
  end
  
end

class WebBuddyPlugin < BBLComponent
  
  def initialize(client, deps = {})
    super client

    deps.map do |ivar_name, obj|
      instance_variable_set "@#{ivar_name}", obj
    end
  end

  def load_view(&load_handler)
    # self.write_data

    client.wc.load_location self.view_url, -> {
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

    # eval_js_file 'modules/assets/js/webbuddy.attach.js'

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
      if (webbuddy.module.scope)
        webbuddy.module.scope.refresh_data();
    )
  end

  # OBSOLETE
  def write_data
    # # write to data/filtering.json TODO fix up prior to release.
    # data_path = NSBundle.mainBundle.path + "/#{module_dir}/data/filtering.json"  # DEPLOY
    data_path = '/Users/ilo-robbie/dev/src/bigbearlabs/webbuddy-modules/output/app/data/filtering.json'  # DEV
    write_file data_path, self.data.to_json  # FIXME this races with the load on filtering.coffee
  end
  
  def eval_js expr
    self.client.wc.eval_js expr
  end
end

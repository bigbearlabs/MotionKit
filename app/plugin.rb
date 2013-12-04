class WebBuddyPlugin < BBLComponent
  
  def initialize(client, deps = {})
    super client

    deps.map do |ivar_name, obj|
      instance_variable_set "@#{ivar_name}", obj
    end
  end

  def load_view
    # self.write_data

    client.wc.load_location self.view_url, -> {
      self.attach_hosting_interface

      yield if block_given?
    }, ignore_history: true
  end

  def view_loaded?
    self.client.wc.browser_vc.url.to_s.include? self.view_url
  end

  # creates the window.webbuddy property.
  # FIXME sometimes this can get clobbered by the stub if it doesn't attach quickly enough.
  def attach_hosting_interface
    pe_log "attaching hosting interface to #{self.view_url}"
    # IMPROVE load from a plugin file.
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

      return window.webbuddy;
    )

    pe_log "eval webbudy.env: #{eval_js 'return webbuddy.env.name'}"
  end

  # OBSOLETE current design suggests modules should directly set data property.
  def update_data data
    pe_log "updating data, keys: #{data.keys}"

    eval_js %(
      return webbuddy.module.update_data(#{data.to_json});
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

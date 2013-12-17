# plugin loaded by AppD, but interacts with wc a lot -- this probably indicates a granularity mismatch.
class WebBuddyPlugin < BBLComponent
  extend Delegating
  def_delegator :'client.wc.browser_vc', :eval_js, :eval_expr, :eval_js_file

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
      ## this is made obsolete by wb-integration.coffee.
      # self.attach_hosting_interface

      load_handler.call
    }
    # , ignore_history: true
  end

  def view_loaded?
    self.client.wc.browser_vc.url.to_s.include? self.view_url
  end

  def attach_hosting_interface
    pe_log "attaching hosting interface to #{self.view_url}"

    eval_js_file 'plugin/assets/js/webbuddy.attach.js'
  end

  def update_data
    data = self.data
    pe_log "updating data, keys: #{data.keys}"

    NSApp.delegate.wc.browser_vc.web_view.delegate.send %(
      window.webbuddy_data = #{self.data.to_json};
      window.webbuddy_data_updated();  // will throw if callback 
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
    pe_log Object.from_json( eval_expr 'webbuddy.module.data').description
  end
  
end

# plugin loaded by AppD, but interacts with wc a lot -- this probably indicates a granularity mismatch.
class WebBuddyPlugin < BBLComponent
  extend Delegating
  include Reactive

  def_delegator :'client.plugin_vc', :eval_js, :eval_expr, :eval_js_file


  def name
    @plugin_name ||= self.class.clean_name.gsub('Plugin', '').downcase
  end
  
  # TODO doesn't work with static plugins.
  def view_url(env = nil)
    default_val = default(:plugin_view_template)
      .gsub( /#\{name\}/, name)
      .gsub( /#\{:app_support_path\}/, NSApp.app_support_path.to_url_encoded)
      .gsub( /#\{:bundle_resources_path\}/, NSApp.bundle_resources_path)
      .split( ', ')
  end
  
  def load_view
    # self.write_data

    pe_log "loading plugin #{self}"

    urls = self.view_url

    self.client.plugin_vc.load_url urls, success_handler: -> url {
      # nothing to do here - view will pull data.
    }
    # , ignore_history: true
  end

  def view_loaded?
    self.view_url.select do |url|
      self.client.plugin_vc.url.to_s.include? url
    end
    .size != 0
  end

  def show_plugin
    self.client.plugin_vc.frame_view.visible = true
    self.client.browser_vc.frame_view.visible = false
  end
  
  def hide_plugin
    self.client.browser_vc.frame_view.visible = true
    self.client.plugin_vc.frame_view.visible = false
  end
  
  def update_data(data = nil)
    data ||= self.data

    pe_log "updating data, keys: #{data.keys}"

    self.client.plugin_vc.web_view.delegate.send %(
      setTimeout( function() {
        window.webbuddy.on_data(#{data.to_json}); 
      }, 0);
    )
  end

  #=

  def inspect_data
    pe_log Object.from_json( eval_expr 'webbuddy.module.data').description
  end
  
end

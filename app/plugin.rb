# plugin loaded by AppD, but interacts with wc a lot -- this probably indicates a granularity mismatch.
class WebBuddyPlugin < BBLComponent
  extend Delegating
  include Reactive

  def_delegator :'client.plugin_vc', :eval_js, :eval_expr, :eval_js_file


  include IvarInjection
  
  def initialize(client, deps = {})
    super client

    inject_collaborators deps
  end


  def name
    @plugin_name ||= self.class.clean_name.gsub('Plugin', '').downcase
  end
  
  # TODO doesn't work with static plugins.
  def view_url(env = nil)
    case env
    when :DEV
      
      default(:plugin_view_template).gsub /#\{.*?\}/, name  # DEV works with 'grunt server' in webbuddy-modules
    else
      plugin_dir = "plugin"
      plugin_view_path = NSBundle.mainBundle.url("#{plugin_dir}/index.html").path
      "file://#{plugin_view_path}#/#{name}"  # DEPLOY
    end
  end
  
  def load_view
    # self.write_data

    pe_log "loading plugin #{self}"

    urls = 
      if RUBYMOTION_ENV == 'development'
        [ self.view_url(:DEV), self.view_url ]
      else
        [ self.view_url]
      end

    self.client.plugin_vc.load_url urls, success_handler: -> url {
      # self.update_data
    }
    # , ignore_history: true
  end

  def view_loaded?
    [self.view_url(:DEV), self.view_url].select do |url|
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

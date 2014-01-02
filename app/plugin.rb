# plugin loaded by AppD, but interacts with wc a lot -- this probably indicates a granularity mismatch.
class WebBuddyPlugin < BBLComponent
  extend Delegating
  include Reactive

  def_delegator :'client.plugin_vc', :eval_js, :eval_expr, :eval_js_file


  include IvarInjection
  
  def initialize(client, deps = {})
    super client

    inject_collaborators deps

    # set up a policy on the web view delegate to prevent href navigation.
    react_to 'client.plugin_vc.web_view_delegate' do |web_view_delegate|
      web_view_delegate.policies_by_pattern = {
        /(localhost|#{NSBundle.mainBundle.path})/ => :load,
        %r{(http://)?about:} => :load,
        /.+/ => -> url, listener {
          pe_log "policy will send #{url} to client."
          
          on_web_view_nav url

          listener.ignore
        },
      }
    end
  end

  def name
    @plugin_name ||= self.class.clean_name.gsub('Plugin', '').downcase
  end
  
  def view_url(env = nil)
    case env
    when :DEV
      
      default(:plugin_view_template).gsub /#\{.*?\}/, name  # DEV works with grunt server in webbuddy-modules
    else
      plugin_dir = "plugin"
      module_index_path = NSBundle.mainBundle.url("#{plugin_dir}/index.html").path
      "file://#{module_index_path}#/#{name}"  # DEPLOY
    end
  end
  
  def load_view(h1 = ->{})
    # self.write_data

    pe_log "loading plugin #{self}"

    urls = 
      if RUBYMOTION_ENV == 'development'
        [ self.view_url(:DEV), self.view_url ]
      else
        [ self.view_url]
      end

    self.client.plugin_vc.load_url urls, success_handler: -> url {
      h1.call
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
  end
  
  def hide_plugin
    self.client.plugin_vc.frame_view.visible = false
  end
  
  def update_data(data = nil)
    data ||= self.data

    pe_log "updating data, keys: #{data.keys}"

    self.client.plugin_vc.web_view.delegate.send %(
      window.webbuddy.on_data(#{data.to_json}); 
    )
  end

  def on_web_view_nav( url )
    # load url. 
    self.client.load_url url

    # TODO restore the stack
  end
  
  #=

  def inspect_data
    pe_log Object.from_json( eval_expr 'webbuddy.module.data').description
  end
  
end

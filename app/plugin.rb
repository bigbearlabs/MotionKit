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
        /.+/ => -> url, listener {
          pe_log "policy will send #{url} to client."
          
          on_web_view_nav url

          listener.ignore
        },
      }
    end
  end

  def view_url(env = nil)
    @plugin_name ||= self.class.clean_name.gsub('Plugin', '').downcase


    case env
    when :DEV
      "http://localhost:9000/#/#{@plugin_name}"  # DEV works with grunt server in webbuddy-modules
    else
      plugin_dir = "plugin"
      module_index_path = NSBundle.mainBundle.url("#{plugin_dir}/index.html").path
      "file://#{module_index_path}#/#{@plugin_name}"  # DEPLOY
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
      ## this is made obsolete by wb-integration.coffee.
      # self.attach_hosting_interface

      yield if block_given?
    }
    # , ignore_history: true
  end

  def view_loaded?
    [self.view_url(:DEV), self.view_url].map do |url|
      self.client.plugin_vc.url.to_s.include? url
    end
  end

  def show_plugin
    self.client.plugin_vc.frame_view.visible = true
  end
  
  def hide_plugin
    self.client.plugin_vc.frame_view.visible = false
  end
  
  def attach_hosting_interface
    pe_log "attaching hosting interface to #{self.view_url}"

    eval_js_file 'plugin/assets/js/webbuddy.attach.js'
  end

  def update_data
    data = self.data
    pe_log "updating data, keys: #{data.keys}"

    self.client.plugin_vc.web_view.delegate.send %(
      window.webbuddy_data = #{self.data.to_json};
      window.webbuddy_data_updated();  // will throw if callback 
    )
  end

  def on_web_view_nav( url )
    # load url. 
    self.client.load_url url

    # TODO restore the stack
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

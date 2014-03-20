

# bridges BBLComponent wiring with the web_vc.
class WebViewComponent < BBLComponent
  include IvarInjection

  def initialize(client, deps)
    super(client)

    inject_collaborators deps

  end

  def on_setup
    init_bridge @web_view

    # setup downloads
    @download_delegate = DownloadDelegate.new downloads_path: default(:downloads_path)
    @web_view.downloadDelegate = @download_delegate
  end

  def defaults_spec
    {
      user_agent: {
        preference_spec: {
          label: "User Agent",
          view_type: :text,
          value: @web_view.user_agent_string
        },
        postflight: -> val {
          NSApp.delegate.viewer_controllers.map do |wc|
            wc.browser_vc.web_view.user_agent_string = val
          end
        },
      },
      # inspector: {
      #   preference_spec: {
      #     label: "Web Inspector",
      #     view_type: :boolean,
      #   },
      #   postflight: -> val {
      #   },
      # },
    } 
  end

#=

  def init_bridge( web_view )
    original_delegate = web_view.delegate
    @bridge = WebViewJavascriptBridge.bridgeForWebView(web_view, 
      webViewDelegate: original_delegate,
      handler: -> data,responseCallback {
        pe_log "Received message from javascript: #{data}"
        responseCallback.call("Right back atcha") if responseCallback
    })
    @bridge.web_view_delegate = original_delegate  # to ensure calls to delegate from other collaborators are handled sensibly.

  end
end
  
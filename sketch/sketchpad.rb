class Sketchpad
  def bridge web_view = NSApp.delegate.wc.browser_vc.web_view
    original_delegate = web_view.delegate
    @bridge = WebViewJavascriptBridge.bridgeForWebView(web_view, 
      webViewDelegate: original_delegate,
      handler: -> data,responseCallback {
        NSLog("Received message from javascript: %@", data)
        responseCallback.call("Right back atcha") if responseCallback
    })
    @bridge.web_view_delegate = original_delegate  # to ensure calls to delegate from other collaborators are handled sensibly.
  end

  def js
    return %Q(
      document.addEventListener('WebViewJavascriptBridgeReady', function onBridgeReady(event) {
        var bridge = event.bridge
        bridge.init(function(message, responseCallback) {
            alert('Received message: ' + message)   
            if (responseCallback) {
                responseCallback("Right back atcha")
            }
        })
        bridge.send('Hello from the javascript')
        bridge.send('Please respond to this', function responseCallback(responseData) {
            console.log("Javascript got its response", responseData)
        })
      }, false)
    )
  end
  
end


class WebViewJavascriptBridge
  extend Delegating
  def_delegator :web_view_delegate

  def web_view_delegate
    @web_view_delegate
  end

  def web_view_delegate=(new_obj)
    @web_view_delegate = new_obj
  end
end
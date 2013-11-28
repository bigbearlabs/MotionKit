PlatformViewController = 
	if BubbleWrap::App.ios?
		UIViewController
	else
		NSViewController
	end


PlatformView = 
  if BubbleWrap::App.ios?
    UIView
  else
    NSView
  end


PlatformWebView = 
  if BubbleWrap::App.ios?
    UIWebView
  else 
    WebView
  end


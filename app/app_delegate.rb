class AppDelegate
  def applicationDidFinishLaunching(notification)
    buildMenu

    window = buildWindow

    add_webviews window.contentView
  end

  def buildWindow
    @mainWindow = NSWindow.alloc.initWithContentRect([[240, 180], [480, 360]],
      styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask,
      backing: NSBackingStoreBuffered,
      defer: false)
    @mainWindow.title = NSBundle.mainBundle.infoDictionary['CFBundleName']
    @mainWindow.orderFrontRegardless

    @mainWindow
  end



  #= webview setup

  def add_webviews to_view
    content_bounds = to_view.bounds

    top_half_frame = CGRectMake( content_bounds.origin.x, content_bounds.origin.y, 
      content_bounds.size.width, content_bounds.size.height / 2 )
    bottom_half_frame = CGRectMake( content_bounds.origin.x, content_bounds.origin.y + content_bounds.size.height / 2, 
      content_bounds.size.width, content_bounds.size.height / 2 )

    webview_1 = new_webview frame: top_half_frame
    webview_2 = new_webview frame: bottom_half_frame

    to_view.addSubview webview_1
    to_view.addSubview webview_2

    webview_1.mainFrameURL = 'http://google.com'
    webview_2.mainFrameURL = 'http://stackoverflow.com'
  end

  def new_webview args
    frameRect = args[:frame]
    frameName = nil
    groupName = nil
    WebView.alloc.initWithFrame(frameRect, frameName:frameName, groupName:groupName)
  end
end

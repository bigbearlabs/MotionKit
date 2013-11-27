class AppDelegate
  include AppBehaviour

  def applicationDidFinishLaunching(notification)
    buildMenu

    # setup_stacks_wc

    setup_viewer_wc
  end

  def setup_viewer_wc
    # MOTION-MIGRATION
    # setup_wc ViewerWindowController

  end
  
  def setup_stacks_wc
    setup_wc DevWindowController, 'stacks_wc'

    view_stacker = WebStacksViewController.alloc.init
    @stacks_wc.add_vc view_stacker
    view_stacker.setup
  end

  #= 

  def buildWindow
    @mainWindow = NSWindow.alloc.initWithContentRect([[240, 180], [480, 360]],
      styleMask: NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask,
      backing: NSBackingStoreBuffered,
      defer: false)
    @mainWindow.title = NSBundle.mainBundle.infoDictionary['CFBundleName']
    @mainWindow.orderFrontRegardless

    @mainWindow
  end

end



# generic wc.
class DevWindowController < NSWindowController
end


# experimental logic to horizontally to webviews with sane scrolling behaviour.
class WebCollectionWindowController < NSWindowController
  extend IB

  outlet :webview_1
  outlet :webview_2

  def awakeFromNib
    super

    # add_webviews window.contentView

    # make inner scroll view pass all scroll events to outer scroll view.
    [ webview_1, webview_2].map do |webview|
      outer_scroll_view = webview.superview.superview.superview
      inner_scroll_view = webview.subviews[0].subviews[0]
      puts "outer: #{outer_scroll_view}"
      puts "inner: #{inner_scroll_view}"

      class << inner_scroll_view
        attr_writer :outer_scroll_view
        def scrollWheel(event)
          @outer_scroll_view.scrollWheel(event)
        end
      end

      inner_scroll_view.outer_scroll_view = outer_scroll_view
    end

    webview_1.mainFrameURL = 'http://google.com'
    webview_2.mainFrameURL = 'http://stackoverflow.com'
  end

   #= webview setup

  def new_webview args
    frameRect = args[:frame]
    frameName = nil
    groupName = nil
    WebView.alloc.initWithFrame(frameRect, frameName:frameName, groupName:groupName)
  end

end
